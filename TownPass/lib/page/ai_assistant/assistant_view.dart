import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:town_pass/page/ai_assistant/navigation_client.dart';
import 'package:town_pass/page/ai_assistant/ai_mascot.dart';
import 'package:town_pass/page/ai_assistant/safe_destinations.dart';

const _teal = Color(0xff00a8ba);

class AssistantView extends StatefulWidget {
  const AssistantView({
    super.key,
    this.client,
    this.inSheet = false,
    this.onInputFocus,
    this.onNavigate,
    this.destinationAvailable,
  });
  final NavigationClient? client;
  final bool inSheet;
  final VoidCallback? onInputFocus;
  final void Function(String)? onNavigate;
  final bool Function(String)? destinationAvailable;
  @override
  State<AssistantView> createState() => _AssistantViewState();
}

class _Message {
  _Message({this.text, this.user = false, this.result, this.query});
  final String? query;
  final String? text;
  final bool user;
  final NavigationResult? result;
  final GlobalKey anchor = GlobalKey();
}

class _AssistantViewState extends State<AssistantView> {
  late final NavigationClient client = widget.client ?? LocalNavigationClient();
  final input = TextEditingController();
  final scroll = ScrollController();
  final messages = <_Message>[];
  bool loading = false;
  bool navigating = false;
  bool _followLatest = true;
  bool _userScrolling = false;
  bool _scrollScheduled = false;
  bool _alignLatestStart = true;

  void _scrollToLatest({bool animate = false, bool force = false}) {
    if ((!_followLatest && !force) || _scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted || !scroll.hasClients || (!_followLatest && !force)) return;
      final latestContext = messages.isEmpty
          ? null
          : messages.last.anchor.currentContext;
      final latestBox = latestContext?.findRenderObject();
      if (!loading &&
          _alignLatestStart &&
          latestContext != null &&
          latestBox is RenderBox &&
          latestBox.size.height > scroll.position.viewportDimension) {
        Scrollable.ensureVisible(
          latestContext,
          alignment: 0,
          duration: animate && !MediaQuery.disableAnimationsOf(context)
              ? const Duration(milliseconds: 200)
              : Duration.zero,
          curve: Curves.easeOut,
        );
        return;
      }
      final target = scroll.position.maxScrollExtent;
      if (animate && !MediaQuery.disableAnimationsOf(context)) {
        scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        scroll.jumpTo(target);
      }
    });
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    if (widget.client == null && client is LocalNavigationClient) {
      (client as LocalNavigationClient).close();
    }
    super.dispose();
  }

  Future<void> send([String? suggestion]) async {
    final query = (suggestion ?? input.text).trim();
    if (query.isEmpty || loading || navigating) return;
    input.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      messages.add(_Message(text: query, user: true));
      loading = true;
      _followLatest = true;
      _alignLatestStart = true;
    });
    _scrollToLatest(animate: true, force: true);
    try {
      final answer = await client.request(query);
      if (!mounted) return;
      final destination = safeAssistantDestination(answer, query);
      if (destination != null && widget.onNavigate != null) {
        if (widget.destinationAvailable?.call(destination.featureId) != true) {
          setState(
            () => messages.add(
              _Message(
                text: destination.featureId == 'activity_information'
                    ? '活動資料尚未準備好，請稍後再試。'
                    : '目前無法開啟這個頁面，請稍後再試。',
              ),
            ),
          );
        } else {
          navigating = true;
          setState(
            () => messages.add(_Message(text: '正在為你開啟${destination.label}…')),
          );
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          if (widget.destinationAvailable?.call(destination.featureId) ==
              true) {
            widget.onNavigate!(destination.featureId);
          } else {
            navigating = false;
            setState(() => messages.add(_Message(text: '頁面目前無法開啟，請稍後再試。')));
          }
        }
      } else {
        setState(() => messages.add(_Message(result: answer, query: query)));
      }
    } on NavigationException catch (e) {
      if (!mounted) return;
      setState(() => messages.add(_Message(text: e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => messages.add(_Message(text: '暫時無法取得預覽，請稍後再試。')));
    } finally {
      if (mounted) {
        setState(() => loading = false);
        _scrollToLatest(animate: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      primary: !widget.inSheet,
      resizeToAvoidBottomInset: !widget.inSheet,
      backgroundColor: const Color(0xffeffafb),
      appBar: AppBar(
        primary: !widget.inSheet,
        automaticallyImplyLeading: !widget.inSheet,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '台北市政 AI 助理',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            Text(
              '本機導航助理',
              style: TextStyle(fontSize: 12, color: Color(0xff64838a)),
            ),
          ],
        ),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              key: const Key('preview-notice'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              color: const Color(0xffd9f5f4),
              child: const Text(
                '可開啟安全頁面，不會執行服務操作',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xff075b65),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    NotificationListener<ScrollMetricsNotification>(
                      onNotification: (_) {
                        if (!_userScrolling && messages.isNotEmpty) {
                          _scrollToLatest();
                        }
                        return false;
                      },
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollStartNotification &&
                              notification.dragDetails != null) {
                            _userScrolling = true;
                          } else if (notification is ScrollUpdateNotification &&
                              notification.dragDetails != null) {
                            _alignLatestStart = false;
                            _followLatest =
                                notification.metrics.extentAfter < 60;
                          } else if (notification is ScrollEndNotification &&
                              _userScrolling) {
                            _followLatest =
                                notification.metrics.extentAfter < 60;
                            _userScrolling = false;
                          }
                          return false;
                        },
                        child: ListView(
                          key: const Key('assistant-messages'),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                          controller: scroll,
                          children: [
                            if (messages.isEmpty)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: math.max(
                                    0,
                                    constraints.maxHeight - 20,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _Welcome(),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 2,
                                      children: [
                                        for (final example in [
                                          '我要查圖書借閱',
                                          '我要看活動訊息',
                                          '我要查看我的票夾',
                                        ])
                                          ActionChip(
                                            label: Text(example),
                                            onPressed: loading
                                                ? null
                                                : () => send(example),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            for (final m in messages)
                              Align(
                                key: m.anchor,
                                alignment: m.user
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 600,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: m.user ? _teal : Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x10228087),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: m.result == null
                                      ? Text(
                                          m.text ?? '',
                                          style: TextStyle(
                                            color: m.user
                                                ? Colors.white
                                                : const Color(0xff183943),
                                            height: 1.5,
                                          ),
                                        )
                                      : _ResultCard(
                                          m.result!,
                                          query: m.query ?? '',
                                          onNavigate: widget.onNavigate,
                                        ),
                                ),
                              ),
                            if (loading)
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text('正在查找導航預覽…'),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('assistant-input'),
                      onTap: () {
                        widget.onInputFocus?.call();
                        _scrollToLatest();
                      },
                      controller: input,
                      maxLength: 2000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => send(),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '輸入問題…',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('assistant-send'),
                    tooltip: '送出',
                    onPressed: loading ? null : () => send(),
                    style: IconButton.styleFrom(backgroundColor: _teal),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        AiMascot(size: 64),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '嗨！我是市政 AI 助理',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff123540),
                ),
              ),
              SizedBox(height: 4),
              Text(
                '告訴我你想找什麼，我會幫你尋找。',
                style: TextStyle(color: Color(0xff64838a)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.result, {required this.query, this.onNavigate});
  final NavigationResult result;
  final String query;
  final void Function(String)? onNavigate;

  @override
  Widget build(BuildContext context) {
    final status = result.preview['status'];
    final feature = result.choice['feature_id'];
    final detail = RegExp(
      r'詳情|詳細|特定|某一|detail|particular',
      caseSensitive: false,
    ).hasMatch(query);
    final message = status == 'rejected'
        ? '抱歉，我無法代替你執行付款、購買或其他服務操作。'
        : detail && (feature == 'activity_information' || query.contains('活動'))
        ? '目前無法直接開啟這個活動詳情，請先選擇活動。'
        : status == 'incomplete'
        ? '目前無法直接開啟這個頁面，所需資料尚未準備好。'
        : '我無法確認你要找的頁面，請換個方式描述。';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        if (kDebugMode)
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              title: const Text('開發者資訊'),
              children: [_DebugResultCard(result, query: query)],
            ),
          ),
      ],
    );
  }
}

class _DebugResultCard extends StatelessWidget {
  const _DebugResultCard(this.result, {required this.query});
  final String query;
  final NavigationResult result;
  String value(Object? v) => v == null
      ? ''
      : v is Map || v is List
      ? v.toString()
      : '$v';
  List<dynamic> list(Object? v) => v is List ? v : const [];
  @override
  Widget build(BuildContext context) {
    final p = result.preview, c = result.choice;
    final status =
        {
          'preview': '可用預覽',
          'incomplete': '路徑未完整',
          'clarify': '需要釐清',
          'rejected': '已拒絕',
        }[p['status']] ??
        '無法預覽';
    final steps = list(p['steps']);
    final boundaries = list(p['recorded_boundary_edges']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          status,
          style: const TextStyle(color: _teal, fontWeight: FontWeight.bold),
        ),
        if (p['feature_name'] != null)
          Text(
            '${value(p['feature_name'])}  ·  ${value(p['feature_id'])}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        Text('意圖：${value(c['intent'])}'),
        const Text('操作權限：無', style: TextStyle(fontWeight: FontWeight.w600)),
        if (p['reason'] != null) Text(value(p['reason'])),
        if (p['screen_id'] != null) Text('目標畫面：${value(p['screen_id'])}'),
        if (p['feature_route'] != null)
          Text('登記路徑：${value(p['feature_route'])}'),
        if (steps.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('來源記錄的步驟', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final step in steps)
            if (step is Map) _step(step),
        ],
        if (boundaries.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            '條件或未完整的邊界（不是完整路徑）',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          for (final b in boundaries)
            if (b is Map) ...[
              for (final step in list(b['prefix_steps']))
                if (step is Map) _step(step),
              _step({
                'from': b['source_screen_id'],
                'to': b['destination_screen_id'] ?? '條件或動態目的地',
                'control_id': b['control_id'],
                'edge_id': b['edge_id'],
                'source': b['source'],
                'required_parameters': b['required_parameters'],
                'prerequisites': b['prerequisites'],
              }),
            ],
        ],
        _items('缺少資料或路徑限制', p['missing']),
        _items('必要參數', p['feature_required_parameters']),
        _items(
          '尚未驗證的前提',
          p['unverified_prerequisites'] ?? p['feature_prerequisites'],
        ),
        _items('已知限制', p['limitations']),
        _items('相依項目', p['dependencies']),
        const SizedBox(height: 8),
        const Text(
          '來源檢視不代表裝置上已驗證。',
          style: TextStyle(color: Color(0xff64838a), fontSize: 12),
        ),
      ],
    );
  }

  Widget _step(Map step) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${value(step['from'])} → ${value(step['to'])}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text('控制：${value(step['control_id'])}  ·  ${value(step['edge_id'])}'),
        if (step['source'] != null)
          Text(
            '來源：${value(step['source'])}',
            style: const TextStyle(fontSize: 12),
          ),
        _items('參數', step['required_parameters']),
        _items('前提', step['prerequisites']),
      ],
    ),
  );
  Widget _items(String label, Object? items) {
    final values = list(items);
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          for (final item in values) Text('• ${value(item)}'),
        ],
      ),
    );
  }
}
