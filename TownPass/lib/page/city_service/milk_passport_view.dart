import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:town_pass/service/milk_passport.dart';
import 'package:town_pass/util/milk_feature_theme.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_card.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_text_styles.dart';

/// A native entry card. No WebView or 3D context exists until a user opens it.
class MilkPassportCard extends StatelessWidget {
  const MilkPassportCard({
    super.key,
    required this.records,
    this.isDemo = false,
  });
  final List<Map<String, dynamic>> records;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final passport = MilkPassport.fromRecords(records);
    return TPCard(
      backgroundColor: TPColors.white,
      cornerRadius: 12,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_outlined, color: TPColors.primary700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '我的鮮奶護照',
                  style: TPTextStyles.h3SemiBold.copyWith(
                    fontSize: 20,
                    color: TPColors.grayscale900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '已收藏 ${passport.count} 枚印章',
            style: TPTextStyles.h3SemiBold.copyWith(color: TPColors.primary800),
          ),
          const SizedBox(height: 6),
          const Text('鮮奶、豆漿都能集章，漏一週也不歸零。', style: TPTextStyles.bodyRegular),
          const SizedBox(height: 6),
          Text(
            '打開護照，翻閱每一週的收藏。',
            style: TPTextStyles.caption.copyWith(color: TPColors.grayscale700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    openMilkPassport(context, records: records, isDemo: isDemo),
                icon: const Icon(Icons.auto_stories_outlined),
                label: const Text('打開護照'),
              ),
              if (passport.count > 0)
                TextButton.icon(
                  onPressed: () => openMilkPassport(
                    context,
                    records: records,
                    isDemo: isDemo,
                    replayLatest: true,
                  ),
                  icon: const Icon(Icons.replay),
                  label: const Text('重播蓋章'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> openMilkPassport(
  BuildContext context, {
  required List<Map<String, dynamic>> records,
  bool isDemo = false,
  bool replayLatest = false,
}) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    builder: (_) => MilkPassportView(
      passport: MilkPassport.fromRecords(records),
      isDemo: isDemo,
      replayLatest: replayLatest,
    ),
  ),
);

class MilkPassportView extends StatefulWidget {
  const MilkPassportView({
    super.key,
    required this.passport,
    this.isDemo = false,
    this.replayLatest = false,
    this.onRendererCreated,
  });
  @visibleForTesting
  final ValueChanged<InAppWebViewController>? onRendererCreated;
  final MilkPassport passport;
  final bool isDemo, replayLatest;
  @override
  State<MilkPassportView> createState() => _MilkPassportViewState();
}

class _MilkPassportViewState extends State<MilkPassportView>
    with WidgetsBindingObserver {
  InAppWebViewController? _controller;
  bool _loading = true,
      _failed = false,
      _injecting = false,
      _background = false;
  Timer? _timeout;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimeout();
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 20), () {
      if (mounted && _loading) _failure();
    });
  }

  Future<void> _send() async {
    if (!mounted || _controller == null || _injecting || _failed) return;
    _injecting = true;
    final generation = _generation;
    final controller = _controller!;
    try {
      final media = MediaQuery.of(context);
      final payload = widget.passport.payload(
        replayLatest: widget.replayLatest,
        reduceMotion: media.disableAnimations || media.accessibleNavigation,
      );
      // JSON encoding prevents record text from becoming executable code. The
      // read-only renderer receives no family credentials or private fields.
      final accepted = await controller.evaluateJavascript(
        source:
            'window.milkPassportHost ? window.milkPassportHost.setRecords(${jsonEncode(payload)}) : false',
      );
      if (accepted == true && mounted && generation == _generation) {
        _timeout?.cancel();
        setState(() => _loading = false);
        if (_background) await _lifecycle('suspend');
      }
    } catch (_) {
      // A document may not be ready yet. onLoadStop and ready callbacks retry;
      // an unavailable renderer falls back to the existing record list.
    } finally {
      if (generation == _generation) _injecting = false;
    }
  }

  Future<void> _lifecycle(String action) async {
    try {
      await _controller?.evaluateJavascript(
        source: 'window.milkPassportHost?.$action()',
      );
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background = state != AppLifecycleState.resumed;
    if (_background) {
      _timeout?.cancel();
    } else if (_loading) {
      _startTimeout();
    }
    unawaited(_lifecycle(_background ? 'suspend' : 'resume'));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeout?.cancel();
    unawaited(_lifecycle('dispose'));
    // The platform view/controller is not kept alive. Removing the route also
    // removes its native WebView and the rendering context it owns.
    _controller = null;
    super.dispose();
  }

  void _failure() {
    if (mounted) {
      _timeout?.cancel();
      unawaited(_lifecycle('dispose'));
      _controller = null;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final generation = _generation;
    return MilkFeatureTheme(
      child: Scaffold(
        appBar: const TPAppBar(title: '我的鮮奶護照'),
        body: SafeArea(
          child: _failed
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      '目前無法開啟立體護照，領取紀錄仍然保留。',
                      style: TPTextStyles.h3SemiBold,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _failed = false;
                          _loading = true;
                          _generation++;
                          _injecting = false;
                        });
                        _startTimeout();
                      },
                      child: const Text('重新開啟護照'),
                    ),
                    const SizedBox(height: 20),
                    if (widget.passport.count == 0) const Text('尚無領取紀錄。'),
                    for (final stamp in widget.passport.stamps)
                      ListTile(
                        leading: const Icon(Icons.bookmark_outline),
                        title: Text(stamp['type'] == 'soy' ? '豆漿' : '鮮奶'),
                        subtitle: Text(stamp['date']!),
                      ),
                  ],
                )
              : Stack(
                  children: [
                    InAppWebView(
                      key: ValueKey(_generation),
                      initialFile: 'assets/passport/passport.html',
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        transparentBackground: false,
                        disableContextMenu: true,
                        supportZoom: false,
                        useShouldOverrideUrlLoading: true,
                        allowFileAccessFromFileURLs: false,
                        allowUniversalAccessFromFileURLs: false,
                        isInspectable: false,
                      ),
                      onWebViewCreated: (controller) {
                        if (!mounted || generation != _generation || _failed) {
                          return;
                        }
                        _controller = controller;
                        widget.onRendererCreated?.call(controller);
                        controller.addJavaScriptHandler(
                          handlerName: 'passportReady',
                          callback: (args) async {
                            if (mounted &&
                                generation == _generation &&
                                identical(controller, _controller)) {
                              await _send();
                            }
                            return true;
                          },
                        );
                      },
                      onLoadStop: (controller, _) async {
                        if (mounted &&
                            generation == _generation &&
                            identical(controller, _controller)) {
                          await _send();
                        }
                      },
                      shouldOverrideUrlLoading: (_, navigation) async {
                        final uri = navigation.request.url;
                        return uri != null &&
                                uri.scheme == 'file' &&
                                uri.path.endsWith(
                                  '/assets/passport/passport.html',
                                )
                            ? NavigationActionPolicy.ALLOW
                            : NavigationActionPolicy.CANCEL;
                      },
                      onPermissionRequest: (_, request) async =>
                          PermissionResponse(
                            resources: request.resources,
                            action: PermissionResponseAction.DENY,
                          ),
                      onReceivedError: (controller, request, _) {
                        if (generation == _generation &&
                            identical(controller, _controller) &&
                            request.isForMainFrame == true) {
                          _failure();
                        }
                      },
                      onWebContentProcessDidTerminate: (controller) {
                        if (generation == _generation &&
                            identical(controller, _controller)) {
                          _failure();
                        }
                      },
                    ),
                    if (_loading)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: TPColors.white,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text('正在打開護照…'),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
