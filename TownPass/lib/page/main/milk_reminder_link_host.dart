import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/page/city_service/milk_service_view.dart';
import 'package:town_pass/service/milk_reminder_target.dart';

/// Drains notification taps after the app navigator exists, including cold start.
class MilkReminderLinkHost extends StatefulWidget {
  const MilkReminderLinkHost({
    super.key,
    required this.child,
    this.navigatorKey,
  });
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;
  @override
  State<MilkReminderLinkHost> createState() => _MilkReminderLinkHostState();
}

class _MilkReminderLinkHostState extends State<MilkReminderLinkHost> {
  bool queued = false;
  String? active;
  @override
  void initState() {
    super.initState();
    MilkReminderNavigation.pending.addListener(_queue);
    _queue();
  }

  void _queue() {
    if (queued || !mounted || MilkReminderNavigation.pending.value == null) {
      return;
    }
    queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      queued = false;
      if (!mounted) return;
      final target = MilkReminderNavigation.pending.value;
      final navigator = (widget.navigatorKey ?? Get.key).currentState;
      if (target == null) return;
      if (navigator == null) {
        _queue();
        return;
      }
      MilkReminderNavigation.pending.value = null;
      if (active == target.payload) return;
      active = target.payload;
      navigator
          .push(
            MaterialPageRoute<void>(
              builder: (_) => MilkServiceView(reminderTarget: target),
            ),
          )
          .whenComplete(() {
            if (active == target.payload) active = null;
          });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    MilkReminderNavigation.pending.removeListener(_queue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
