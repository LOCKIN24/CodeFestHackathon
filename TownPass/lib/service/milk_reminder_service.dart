import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/service/milk_family_store.dart';
import 'package:town_pass/service/milk_family_sync.dart';
import 'package:town_pass/service/milk_reminder_target.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class MilkPlannedReminder {
  const MilkPlannedReminder({
    required this.id,
    required this.target,
    required this.scheduledAt,
    required this.body,
  });
  final int id;
  final MilkReminderTarget target;
  final tz.TZDateTime scheduledAt;
  final String body;
}

/// Local reminders reflect on-device records, not official eligibility.
class MilkReminderService {
  static const _firstId = 71000;
  // Leave room below iOS's pending-notification limit for unrelated app notices.
  static const _slots = 48;
  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<void> _queue = Future.value();

  /// [now] is an instant; all calendar calculations use Asia/Taipei.
  /// IDs occupy the reserved range. Logical targets and dates remain the same
  /// when another child's reminders are removed, although slot IDs may shift.
  static List<MilkPlannedReminder> plan(
    Iterable<Map<String, dynamic>> children, {
    required String role,
    required DateTime now,
  }) {
    if (role != 'parent' && role != 'child') return const [];
    tzdata.initializeTimeZones();
    final taipei = tz.getLocation('Asia/Taipei');
    final localNow = tz.TZDateTime.from(now, taipei);
    final monday = tz.TZDateTime(
      taipei,
      localNow.year,
      localNow.month,
      localNow.day,
    ).subtract(Duration(days: localNow.weekday - 1));
    final profiles = children
        .where(
          (c) =>
              c['id'] is String &&
              RegExp(r'^[0-9a-f]{32}$').hasMatch(c['id'] as String),
        )
        .toList();
    final planned = <MilkPlannedReminder>[];
    // Generate chronologically so the cap keeps the soonest reminders for all
    // children, rather than reserving eight weeks for the first child only.
    for (var week = 0; week < 8; week++) {
      final weekStart = monday.add(Duration(days: week * 7));
      final pending = MilkReminderTarget.pending(
        profiles,
        role: role,
        now: weekStart,
      );
      for (final day in [2, 6]) {
        final scheduled = weekStart.add(Duration(days: day, hours: 9));
        if (!scheduled.isAfter(localNow)) continue;
        for (final target in pending) {
          if (planned.length == _slots) return planned;
          planned.add(
            MilkPlannedReminder(
              id: _firstId + planned.length,
              target: target,
              scheduledAt: scheduled,
              body:
                  '${target.name}：本週鮮奶提醒。'
                  '${day == 6 ? '今天是本週最後一天，' : ''}記得攜帶實體卡證確認兌領。',
            ),
          );
        }
      }
    }
    return planned;
  }

  static Future<void> refresh() {
    // Serialize cancel/recreate operations across saves, role changes and resume.
    _queue = _queue.then((_) => _refresh()).catchError((Object error) {
      debugPrint('Milk reminder scheduling failed: $error');
    });
    return _queue;
  }

  static Future<void> _refresh() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      return;
    }
    // Cancel first, including the old sixteen IDs. Revoked/missing child cache
    // must remove existing reminders without reading the parent's local store.
    for (var id = _firstId; id < _firstId + _slots; id++) {
      await _plugin.cancel(id: id);
    }
    if ((await SharedPreferences.getInstance()).getBool(
          'notifications_enabled',
        ) ==
        false) {
      return;
    }
    final childMode = await MilkFamilySync.isChild;
    final List<Map<String, dynamic>> profiles;
    if (childMode) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('milk_child_cache');
      if (raw == null) return;
      try {
        final child = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final localName = prefs.getString('milk_child_local_name')?.trim();
        if (localName != null && localName.isNotEmpty) {
          child['name'] = localName;
        }
        profiles = [child];
      } catch (_) {
        return;
      }
    } else {
      profiles = (await MilkFamilyStore.load()).map((c) => c.toJson()).toList();
    }
    final reminders = plan(
      profiles,
      role: childMode ? 'child' : 'parent',
      now: DateTime.now(),
    );
    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: '鮮奶週報提醒',
        body: reminder.body,
        scheduledDate: reminder.scheduledAt,
        payload: reminder.target.payload,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'milk_reminders',
            '鮮奶兌領提醒',
            channelDescription: '每週三與週日上午提醒',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
