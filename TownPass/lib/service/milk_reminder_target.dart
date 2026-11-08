import 'dart:convert';

import 'package:flutter/foundation.dart';

/// A reminder contains a role-scoped child ID, never a card number or name.
class MilkReminderTarget {
  const MilkReminderTarget({
    required this.childId,
    required this.name,
    required this.role,
    required this.week,
  });
  final String childId, name, role, week;

  static String weekOf(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day)
          .subtract(Duration(days: date.weekday - 1))
          .toIso8601String()
          .substring(0, 10);

  String get payload => jsonEncode({
    'kind': 'milk_reminder_v1',
    'childId': childId,
    'role': role,
    'week': week,
  });

  static MilkReminderTarget? decode(String? payload) {
    if (payload == null) return null;
    try {
      final p = jsonDecode(payload) as Map<String, dynamic>;
      if (p['kind'] != 'milk_reminder_v1' ||
          !['parent', 'child'].contains(p['role']) ||
          p['childId'] is! String ||
          !RegExp(r'^[0-9a-f]{32}$').hasMatch(p['childId'] as String) ||
          p['week'] is! String ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(p['week'] as String)) {
        return null;
      }
      return MilkReminderTarget(
        childId: p['childId'] as String,
        name: '',
        role: p['role'] as String,
        week: p['week'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  static List<MilkReminderTarget> pending(
    Iterable<Map<String, dynamic>> children, {
    required String role,
    required DateTime now,
  }) {
    final week = weekOf(now);
    return [
      for (final c in children)
        if (!(c['records'] as List? ?? []).any(
          (r) => r is Map && r['week'] == week,
        ))
          MilkReminderTarget(
            childId: c['id'] as String,
            name: (c['name'] ?? c['alias'] ?? '孩子') as String,
            role: role,
            week: week,
          ),
    ];
  }
}

class MilkReminderNavigation {
  static final pending = ValueNotifier<MilkReminderTarget?>(null);
  static void receive(String? payload) {
    final target = MilkReminderTarget.decode(payload);
    if (target != null) pending.value = target;
  }
}
