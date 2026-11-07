import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:town_pass/page/ai_assistant/ai_mascot.dart';
import 'package:town_pass/util/tp_bottom_navigation_factory.dart';
import 'package:town_pass/util/tp_colors.dart';

/// The four values remain the original IndexedStack indices.
class AssistantBottomNavigation extends StatelessWidget {
  const AssistantBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.openAssistant,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final Future<void> Function() openAssistant;

  @override
  Widget build(BuildContext context) {
    final items = TPBottomNavigationFactory.barItemList;
    Widget tab(int index) {
      final selected = currentIndex == index;
      final color = selected ? TPColors.primary500 : TPColors.grayscale950;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: items[index].label,
          onTap: () => onSelect(index),
          child: ExcludeSemantics(
            child: InkWell(
              key: ValueKey('navigation-tab-$index'),
              onTap: () => onSelect(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme(
                    data: IconThemeData(size: 24, color: color),
                    child: items[index].icon,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[index].label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: MediaQuery.textScalerOf(context)
                        .clamp(maxScaleFactor: 1.25),
                    style: TextStyle(color: color, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        const Positioned.fill(
          top: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x140B0D0E),
                  blurRadius: 16,
                  offset: Offset(0, -10),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: SizedBox(
            height: 76,
            child: Row(
              children: [
                tab(0),
                tab(2),
                Expanded(
                  child: Center(
                    child: _AssistantLauncher(openAssistant: openAssistant),
                  ),
                ),
                tab(1),
                tab(3),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AssistantLauncher extends StatefulWidget {
  const _AssistantLauncher({required this.openAssistant});
  final Future<void> Function() openAssistant;

  @override
  State<_AssistantLauncher> createState() => _AssistantLauncherState();
}

class _AssistantLauncherState extends State<_AssistantLauncher>
    with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _idle.stop();
      _idle.value = 0;
    } else if (!_idle.isAnimating) {
      _idle.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _pulse.dispose();
    super.dispose();
  }

  bool _pressed = false;
  bool _opening = false;
  double _dragDistance = 0;

  void _setPressed(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  Future<void> _open({bool longPress = false}) async {
    if (_opening) return;
    _opening = true;
    final reduced = MediaQuery.disableAnimationsOf(context);
    _setPressed(true);
    if (longPress) HapticFeedback.mediumImpact();
    if (!reduced) _pulse.forward(from: 0);
    if (!mounted) return;
    try {
      await widget.openAssistant();
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: 'AI 助理',
      onTap: _open,
      onLongPress: () => _open(longPress: true),
      child: ExcludeSemantics(
        child: Listener(
          onPointerDown: (_) => _setPressed(true),
          onPointerUp: (_) => _setPressed(false),
          onPointerCancel: (_) => _setPressed(false),
          child: GestureDetector(
            key: const Key('assistant-launcher'),
            behavior: HitTestBehavior.opaque,
            onTapCancel: () => _setPressed(false),
            onTap: _open,
            onLongPress: () => _open(longPress: true),
            onLongPressEnd: (_) => _setPressed(false),
            onVerticalDragStart: (_) {
              _dragDistance = 0;
              _setPressed(false);
            },
            onVerticalDragUpdate: (details) =>
                _dragDistance += details.delta.dy,
            onVerticalDragEnd: (_) {
              _setPressed(false);
              if (_dragDistance < -25) _open();
            },
            onVerticalDragCancel: () => _setPressed(false),
            child: SizedBox(
              width: 68,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([_idle, _pulse]),
                    builder: (context, _) => Transform.translate(
                      key: const Key('mascot-bob'),
                      offset: Offset(
                        0,
                        -math.sin(_idle.value * math.pi / 2) * 3,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          if (_pulse.isAnimating)
                            Opacity(
                              opacity: (1 - _pulse.value).clamp(0, 1),
                              child: Transform.scale(
                                scale: 1 + _pulse.value * .65,
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xff7ce5e6),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          AnimatedScale(
                            scale: _pressed ? .9 : 1,
                            duration: reducedMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 130),
                            curve: Curves.easeOut,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xff96ebe8),
                                    Color(0xff00bfd0),
                                    Color(0xff0097b6),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: const Color(0xffd5fbf9),
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x5500adbc),
                                    blurRadius: 12,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: AiMascot(size: 46),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AI 助理',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: MediaQuery.textScalerOf(context)
                        .clamp(maxScaleFactor: 1.15),
                    style: const TextStyle(
                      color: Color(0xff0097a7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
