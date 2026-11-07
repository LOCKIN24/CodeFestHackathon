import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:town_pass/page/ai_assistant/assistant_view.dart';
import 'package:town_pass/page/ai_assistant/safe_destinations.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:get/get.dart';
import 'package:town_pass/page/home/widget/activity_info/activity_banner_widget_controller.dart';

bool assistantDestinationAvailable(String id) {
  final destination = assistantDestinations[id];
  if (destination == null ||
      Get.key.currentState == null ||
      Get.currentRoute != TPRoute.main ||
      !TPRoute.page.any((page) => page.name == destination.route)) {
    return false;
  }
  if (id == 'activity_information') {
    if (!Get.isRegistered<ActivityBannerWidgetController>()) return false;
    final controller = Get.find<ActivityBannerWidgetController>();
    return !controller.isLoading && controller.list != null;
  }
  return true;
}

Future<void> showAssistantSheet(BuildContext context) async {
  final destinationId = await showGeneralDialog<String>(
    context: context,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (_, _, _) => const AssistantSheet(),
  );
  if (!context.mounted || destinationId == null) return;
  final destination = assistantDestinations[destinationId];
  if (destination == null || !assistantDestinationAvailable(destinationId)) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(const SnackBar(content: Text('目前無法開啟此頁面。')));
    return;
  }
  try {
    if (destinationId == 'activity_information') {
      final list = Get.find<ActivityBannerWidgetController>().list;
      if (list == null) throw StateError('Activity data unavailable');
      await Get.toNamed(TPRoute.activityList, arguments: list);
    } else {
      await Get.toNamed(destination.route);
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(const SnackBar(content: Text('目前無法開啟此頁面。')));
    }
  }
}

/// A single progress value controls the scrim, entry, drag and settling.
class AssistantSheet extends StatefulWidget {
  const AssistantSheet({super.key});

  @override
  State<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<AssistantSheet>
    with SingleTickerProviderStateMixin {
  static const double _partial = .66;
  late final AnimationController _position;
  bool _closing = false;
  bool _allowPop = false;
  double _available = 1;

  @override
  void initState() {
    super.initState();
    _position = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_closing) _settle(_partial);
    });
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  Future<void> _settle(double target, {double velocity = 0}) async {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = target;
      return;
    }
    final distance = (target - _position.value).abs();
    final ms = velocity.abs() > 500
        ? (distance * _available / velocity.abs() * 1000).clamp(140.0, 360.0)
        : (distance / _partial * 340).clamp(160.0, 400.0);
    await _position.animateTo(
      target,
      duration: Duration(milliseconds: ms.round()),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _dismiss([String? destinationId]) async {
    if (_closing) return;
    _closing = true;
    FocusScope.of(context).unfocus();
    await _settle(0);
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop(destinationId);
  }

  void _expand() {
    if (!_closing) _settle(1);
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (_closing) return;
    _position.stop();
    _position.value = (_position.value - details.delta.dy / _available).clamp(
      0,
      1,
    );
  }

  void _dragEnd(DragEndDetails details) {
    if (_closing) return;
    final velocity = details.primaryVelocity ?? 0;
    final current = _position.value;
    if (velocity > 500) {
      if (current > _partial + .08) {
        FocusScope.of(context).unfocus();
        _settle(_partial, velocity: velocity);
      } else {
        _dismiss();
      }
    } else if (velocity < -500) {
      _settle(1, velocity: velocity);
    } else if (current < _partial * .55) {
      _dismiss();
    } else {
      _settle(current > (_partial + 1) / 2 ? 1 : _partial, velocity: velocity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    _available = math.max(1, media.size.height - media.padding.top - keyboard);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (MediaQuery.viewInsetsOf(context).bottom > 0) {
          FocusScope.of(context).unfocus();
        } else {
          _dismiss();
        }
      },
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _position,
          child: Column(
            children: [
              Semantics(
                label: '關閉 AI 助理',
                hint: '點兩下關閉；也可向上展開或向下收合',
                button: true,
                onTap: () => _dismiss(),
                onIncrease: _expand,
                onDecrease: () {
                  if (!_closing) _settle(_partial);
                },
                child: ExcludeSemantics(
                  child: GestureDetector(
                    key: const Key('assistant-sheet-handle'),
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: _dragUpdate,
                    onVerticalDragEnd: _dragEnd,
                    onVerticalDragCancel: () {
                      if (!_closing) _settle(_partial);
                    },
                    child: SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: Center(
                        child: Container(
                          width: 39,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xffa7ced0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: AssistantView(
                    inSheet: true,
                    onInputFocus: _expand,
                    onNavigate: (id) => _dismiss(id),
                    destinationAvailable: assistantDestinationAvailable,
                  ),
                ),
              ),
            ],
          ),
          builder: (context, child) {
            final position = _position.value;
            final height = math.max(_partial, position) * _available;
            final offset = math.max(0.0, _partial - position) * _available;
            return Stack(
              children: [
                Positioned.fill(
                  child: Semantics(
                    label: '關閉 AI 助理',
                    button: true,
                    onTap: () => _dismiss(),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _dismiss(),
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: .45 * (position / _partial).clamp(0, 1),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: keyboard - offset,
                  child: SizedBox(
                    key: const Key('assistant-sheet'),
                    height: height,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      child: ColoredBox(
                        color: const Color(0xffeffafb),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
