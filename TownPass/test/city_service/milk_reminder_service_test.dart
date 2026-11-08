import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/service/milk_family_store.dart';
import 'package:town_pass/service/milk_reminder_service.dart';
import 'package:town_pass/service/milk_reminder_target.dart';

const _first = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _second = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

Map<String, dynamic> _child(
  String id,
  String name, {
  List<String> weeks = const [],
}) => {
  'id': id,
  'name': name,
  'number': 'private-card-sentinel',
  'school': 'private-school-sentinel',
  'records': [
    for (final week in weeks) {'week': week, 'product': '鮮奶', 'date': 'test'},
  ],
};

String _logical(MilkPlannedReminder item) =>
    '${item.target.payload}|${item.scheduledAt.toIso8601String()}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Wednesday and Sunday reminders use Taipei 09:00 and the correct Monday week', () {
    // This instant is Monday 00:01 in Taipei while UTC is still Sunday.
    final plan = MilkReminderService.plan(
      [_child(_first, '孩子甲')],
      role: 'parent',
      now: DateTime.utc(2026, 11, 8, 16, 1),
    );
    expect(plan, hasLength(16));
    expect(
      plan.first.scheduledAt.toIso8601String(),
      '2026-11-11T09:00:00.000+0800',
    );
    expect(plan.first.target.week, '2026-11-09');
    expect(plan.first.scheduledAt.timeZoneOffset, const Duration(hours: 8));
    expect(
      plan.every(
        (item) => [
          DateTime.wednesday,
          DateTime.sunday,
        ].contains(item.scheduledAt.weekday),
      ),
      isTrue,
    );
    expect(
      plan.every(
        (item) => item.scheduledAt.hour == 9 && item.scheduledAt.minute == 0,
      ),
      isTrue,
    );
    expect(plan.last.target.week, '2026-12-28');
  });

  test(
    'past or exactly-due reminders are skipped rather than emitted immediately',
    () {
      final instant = DateTime.utc(2026, 11, 4, 1); // Wednesday 09:00 Taipei.
      final plan = MilkReminderService.plan(
        [_child(_first, '孩子甲')],
        role: 'parent',
        now: instant,
      );
      expect(plan.first.scheduledAt.weekday, DateTime.sunday);
      expect(plan.every((item) => item.scheduledAt.isAfter(instant)), isTrue);
      expect(plan, hasLength(15));
    },
  );

  test('collection removes only that child and that week while sibling and future reminders remain', () {
    final now = DateTime.utc(2026, 11, 2, 0); // Monday Taipei.
    final before = MilkReminderService.plan(
      [_child(_first, '孩子甲'), _child(_second, '孩子乙')],
      role: 'parent',
      now: now,
    );
    final after = MilkReminderService.plan(
      [
        _child(_first, '孩子甲', weeks: ['2026-11-02']),
        _child(_second, '孩子乙'),
      ],
      role: 'parent',
      now: now,
    );
    final expected = before
        .where(
          (item) =>
              !(item.target.childId == _first &&
                  item.target.week == '2026-11-02'),
        )
        .map(_logical)
        .toSet();
    expect(after.map(_logical).toSet(), expected);
    expect(
      after.where(
        (item) =>
            item.target.childId == _second && item.target.week == '2026-11-02',
      ),
      hasLength(2),
    );
    expect(
      after.where(
        (item) =>
            item.target.childId == _first && item.target.week == '2026-11-09',
      ),
      hasLength(2),
    );
  });

  test(
    'each future week checks its own records rather than only the current week',
    () {
      final plan = MilkReminderService.plan(
        [
          _child(_first, '孩子甲', weeks: ['2026-11-09']),
        ],
        role: 'parent',
        now: DateTime.utc(2026, 11, 2),
      );
      expect(plan.where((item) => item.target.week == '2026-11-09'), isEmpty);
      expect(
        plan.where((item) => item.target.week == '2026-11-02'),
        hasLength(2),
      );
      expect(
        plan.where((item) => item.target.week == '2026-11-16'),
        hasLength(2),
      );
    },
  );

  test('the 48-slot cap keeps earliest reminders for all children', () {
    final profiles = [
      for (final id in ['a', 'b', 'c', 'd']) _child(id * 32, '孩子$id'),
    ];
    final plan = MilkReminderService.plan(
      profiles,
      role: 'parent',
      now: DateTime.utc(2026, 11, 2),
    );
    expect(plan, hasLength(48));
    expect(plan.map((item) => item.id).toSet(), hasLength(48));
    expect(plan.every((item) => item.id >= 71000 && item.id <= 71047), isTrue);
    for (var i = 1; i < plan.length; i++) {
      expect(plan[i].scheduledAt.isBefore(plan[i - 1].scheduledAt), isFalse);
    }
    expect(
      plan.take(8).map((item) => item.target.childId).toSet(),
      profiles.map((c) => c['id']).toSet(),
    );
    expect(
      plan.last.target.week,
      '2026-12-07',
    ); // Six weeks fit for four children.
  });

  test('notification payload routes by role/id/week without carrying personal fields', () {
    final target = MilkReminderService.plan(
      [_child(_first, 'PRIVATE-NAME-SENTINEL')],
      role: 'parent',
      now: DateTime.utc(2026, 11, 2),
    ).first;
    expect(target.body, contains('PRIVATE-NAME-SENTINEL'));
    expect(target.body, contains('本週鮮奶提醒'));
    final decoded = jsonDecode(target.target.payload) as Map;
    expect(decoded.keys.toSet(), {'kind', 'childId', 'role', 'week'});
    expect(target.target.payload, isNot(contains('PRIVATE-NAME-SENTINEL')));
    expect(target.target.payload, isNot(contains('private-card-sentinel')));
    expect(target.target.payload, isNot(contains('private-school-sentinel')));
    expect(MilkReminderTarget.decode(target.target.payload)!.childId, _first);
  });

  group('native scheduling boundary', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    late List<MethodCall> calls;
    late Map<int, Map<String, dynamic>> pending;
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      FlutterLocalNotificationsPlatform.instance =
          IOSFlutterLocalNotificationsPlugin();
      calls = [];
      pending = {
        42: {'body': 'unrelated app notice'},
        71000: {'body': 'legacy milk notice'},
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'cancel') {
              pending.remove(call.arguments as int);
            }
            if (call.method == 'zonedSchedule') {
              final args = Map<String, dynamic>.from(call.arguments as Map);
              pending[args['id'] as int] = args;
            }
            return null;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test(
      'disabled notifications remove milk reminders and do not reschedule',
      () async {
        SharedPreferences.setMockInitialValues({
          'notifications_enabled': false,
          MilkFamilyStore.key: jsonEncode([_child(_first, '孩子甲')]),
        });
        await MilkReminderService.refresh();
        expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
        expect(pending.keys, [42]);
      },
    );

    test('parent schedules child-specific payloads and cleans the entire reserved range', () async {
      SharedPreferences.setMockInitialValues({
        MilkFamilyStore.key: jsonEncode([
          _child(_first, '孩子甲'),
          _child(_second, '孩子乙'),
        ]),
      });
      await MilkReminderService.refresh();
      final scheduled = calls
          .where((c) => c.method == 'zonedSchedule')
          .toList();
      expect(scheduled, isNotEmpty);
      final targets = scheduled
          .map(
            (c) => MilkReminderTarget.decode(
              (c.arguments as Map)['payload'] as String,
            )!,
          )
          .toList();
      expect(targets.map((t) => t.childId).toSet(), {_first, _second});
      expect(targets.every((t) => t.role == 'parent'), isTrue);
      expect(
        calls
            .where((c) => c.method == 'cancel')
            .map((c) => c.arguments as int)
            .toSet(),
        {for (var id = 71000; id <= 71047; id++) id},
      );
      expect(pending[42]!['body'], 'unrelated app notice');
      expect(pending[71000]!['body'], isNot('legacy milk notice'));
      expect(
        scheduled.every(
          (c) => ((c.arguments as Map)['body'] as String).contains('本週鮮奶提醒'),
        ),
        isTrue,
      );
    });

    test(
      'child mode reads only its own cached profile and locally chosen name',
      () async {
        SharedPreferences.setMockInitialValues({
          'milk_sync_child_token': 'test-child-token',
          'milk_child_cache': jsonEncode({
            'id': _second,
            'alias': 'shared alias',
            'records': [],
          }),
          'milk_child_local_name': '本機暱稱',
          MilkFamilyStore.key: 'parent data must not be read as JSON',
        });
        await MilkReminderService.refresh();
        final scheduled = calls
            .where((c) => c.method == 'zonedSchedule')
            .toList();
        expect(scheduled, isNotEmpty);
        for (final call in scheduled) {
          final args = call.arguments as Map;
          final target = MilkReminderTarget.decode(args['payload'] as String)!;
          expect(target.childId, _second);
          expect(target.role, 'child');
          expect(args['body'], contains('本機暱稱'));
          expect(args['payload'], isNot(contains('本機暱稱')));
        }
      },
    );

    test('missing or corrupt revoked-child cache removes old notices without parent fallback', () async {
      for (final raw in <String?>[null, '{broken json']) {
        final prefs = <String, Object>{
          'milk_sync_child_token': 'revoked-child-token',
          MilkFamilyStore.key: jsonEncode([_child(_first, '親端資料不得使用')]),
        };
        if (raw != null) prefs['milk_child_cache'] = raw;
        SharedPreferences.setMockInitialValues(prefs);
        calls.clear();
        pending[71047] = {'body': 'old child notice'};
        await MilkReminderService.refresh();
        expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
        expect(pending.keys, {42});
      }
    });
  });
}
