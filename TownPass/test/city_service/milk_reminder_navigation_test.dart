import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/page/main/milk_reminder_link_host.dart';
import 'package:town_pass/page/main/milk_daily_notice.dart';
import 'package:town_pass/page/city_service/milk_service_view.dart';
import 'package:town_pass/service/milk_family_store.dart';
import 'package:town_pass/service/milk_reminder_target.dart';

MilkReminderTarget _target(String id, {String role = 'parent'}) =>
    MilkReminderTarget(
      childId: id,
      name: '只在手機顯示的名字',
      role: role,
      week: '2026-11-02',
    );

void _family({bool childRole = false}) {
  SharedPreferences.setMockInitialValues({
    MilkFamilyStore.key: jsonEncode([
      {
        'id': 'a' * 32,
        'name': '小明',
        'number': '0123456789012345',
        'school': '第一所學校',
        'records': [],
      },
      {
        'id': 'b' * 32,
        'name': '小美',
        'number': '1234567890123456',
        'school': '第二所學校',
        'records': [],
      },
    ]),
    MilkFamilyStore.selectedKey: 'a' * 32,
    if (childRole) 'milk_sync_child_token': 'test-child-token',
  });
}

Future<void> _app(WidgetTester tester, {bool notice = false}) async {
  final key = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: key,
      builder: (context, child) =>
          MilkReminderLinkHost(navigatorKey: key, child: child!),
      home: notice
          ? const MilkDailyNotice(child: Scaffold(body: Text('Home')))
          : const Scaffold(body: Text('Home')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => MilkReminderNavigation.pending.value = null);
  tearDown(() => MilkReminderNavigation.pending.value = null);

  test('payload routes by child ID and role without private display data', () {
    final t = _target('b' * 32);
    expect(t.payload, isNot(contains(t.name)));
    expect(t.payload, isNot(contains('0123456789012345')));
    final decoded = MilkReminderTarget.decode(t.payload)!;
    expect(decoded.childId, 'b' * 32);
    expect(decoded.role, 'parent');
    for (final invalid in [
      null,
      'https://example.com',
      '{}',
      '[1]',
      '{',
      jsonEncode({
        'kind': 'milk_reminder_v1',
        'childId': 'b' * 32,
        'role': 'demo',
        'week': '2026-11-02',
      }),
      jsonEncode({
        'kind': 'milk_reminder_v1',
        'childId': '',
        'role': 'parent',
        'week': '2026-11-02',
      }),
    ]) {
      expect(MilkReminderTarget.decode(invalid), isNull);
    }
  });

  testWidgets(
    'cold-start notification opens the named child instead of saved selection',
    (tester) async {
      _family();
      MilkReminderNavigation.receive(_target('b' * 32).payload);
      await _app(tester);
      expect(find.byType(MilkServiceView), findsOneWidget);
      expect(find.text('第二所學校'), findsOneWidget);
      expect(find.text('第一所學校'), findsNothing);
      expect(MilkReminderNavigation.pending.value, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'warm notification selects child and duplicate taps do not stack routes',
    (tester) async {
      _family();
      await _app(tester);
      MilkReminderNavigation.receive(_target('b' * 32).payload);
      await tester.pumpAndSettle();
      MilkReminderNavigation.receive(_target('b' * 32).payload);
      await tester.pumpAndSettle();
      expect(find.byType(MilkServiceView, skipOffstage: false), findsOneWidget);
      expect(find.text('第二所學校'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('removed child notification does not fall back to a sibling', (
    tester,
  ) async {
    _family();
    MilkReminderNavigation.receive(_target('c' * 32).payload);
    await _app(tester);
    expect(find.textContaining('這位子女已移除'), findsOneWidget);
    expect(find.text('第一所學校'), findsNothing);
    expect(find.text('第二所學校'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('parent notification cannot open parent records in child mode', (
    tester,
  ) async {
    _family(childRole: true);
    MilkReminderNavigation.receive(_target('a' * 32).payload);
    await _app(tester);
    expect(find.textContaining('目前的帳號角色不符'), findsOneWidget);
    expect(find.text('第一所學校'), findsNothing);
    expect(find.text('第二所學校'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'cold-start notice does not obscure the notification destination',
    (tester) async {
      _family();
      MilkReminderNavigation.receive(_target('b' * 32).payload);
      await _app(tester, notice: true);
      expect(find.text('鮮奶週週報到！'), findsNothing);
      expect(find.text('第二所學校'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
