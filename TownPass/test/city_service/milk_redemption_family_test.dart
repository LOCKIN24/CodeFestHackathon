import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/service/milk_family_store.dart';
import 'package:town_pass/service/milk_redemption_demo.dart';

MilkChild _child(
  String id,
  String name, {
  List<Map<String, dynamic>> records = const [],
  Map<String, dynamic>? outing,
}) => MilkChild(
  id: id,
  number: '0123456789012345',
  name: name,
  school: '私有學校',
  records: records,
  outing: outing,
);
String _week() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  return DateTime.utc(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1))
      .toIso8601String()
      .substring(0, 10);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'milk_sync_parent_token': 'parent-sentinel',
    }),
  );

  test('family collection uses the actual selected family and updates only its pickup/passport record', () async {
    final a = _child(
      'a' * 32,
      '小明',
      outing: {'week': _week(), 'status': 'planned', 'revision': 2},
    );
    final b = _child('b' * 32, '小安');
    await MilkFamilyStore.save([a, b]);
    final session = await MilkRedemptionDemo.openFamily();
    expect(session.url, MilkRedemptionDemo.familyLocalAddress);
    expect(session.children.map((c) => c['alias']), ['小明', '小安']);
    expect(jsonEncode(session.children), isNot(contains(a.number)));
    expect(jsonEncode(session.children), isNot(contains(a.school)));
    final result = await MilkRedemptionDemo.redeem(
      session,
      'FAMILY-${a.id}',
      '豆漿',
    );
    expect(result.result, 'accepted');
    final stored = await MilkFamilyStore.load();
    expect(stored.first.records.single['product'], '豆漿');
    expect(stored.first.records.single['source'], 'demo_transaction');
    expect(stored.first.records.single['confirmedAt'], endsWith('+08:00'));
    expect(stored.first.outing!['status'], 'completed');
    expect(stored.first.outing!['revision'], 3);
    expect(stored.first.number, a.number);
    expect(stored.last.toJson(), b.toJson());
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('milk_sync_parent_token'), 'parent-sentinel');
    expect(prefs.getString(MilkRedemptionDemo.preferenceKey), isNull);
  });

  test('family reopen/replay and simultaneous submits retain the original transaction', () async {
    final a = _child('a' * 32, '小明');
    await MilkFamilyStore.save([a]);
    final session = await MilkRedemptionDemo.openFamily();
    final result = await Future.wait([
      MilkRedemptionDemo.redeem(session, 'FAMILY-${a.id}', '鮮奶'),
      MilkRedemptionDemo.redeem(session, 'FAMILY-${a.id}', '豆漿'),
    ]);
    expect(result.map((r) => r.result), ['accepted', 'duplicate_transaction']);
    final reopened = await MilkRedemptionDemo.openFamily();
    expect(reopened.children.single['records'], result.first.child['records']);
    final replay = await MilkRedemptionDemo.redeem(
      reopened,
      'FAMILY-${a.id}',
      '豆漿',
      repeat: true,
    );
    expect(replay.result, 'duplicate_transaction');
    final event = await MilkRedemptionDemo.lastEvent(
      reopened,
      'FAMILY-${a.id}',
    );
    expect(event!['product'], '鮮奶');
    expect((await MilkFamilyStore.load()).single.records.length, 1);
  });

  test('already recorded week never changes drink or creates a competing visible event', () async {
    final a = _child(
      'a' * 32,
      '小明',
      records: [
        {'week': _week(), 'product': '鮮奶', 'date': '2026/11/08 10:00'},
      ],
    );
    await MilkFamilyStore.save([a]);
    final session = await MilkRedemptionDemo.openFamily();
    final result = await MilkRedemptionDemo.redeem(
      session,
      'FAMILY-${a.id}',
      '豆漿',
    );
    expect(result.result, 'already_recorded');
    expect((await MilkFamilyStore.load()).single.toJson(), a.toJson());
    expect(
      await MilkRedemptionDemo.lastEvent(session, 'FAMILY-${a.id}'),
      isNull,
    );
  });

  test('removed children are never recreated and latest sibling edits survive collection', () async {
    final a = _child('a' * 32, '小明'), b = _child('b' * 32, '小安');
    await MilkFamilyStore.save([a, b]);
    final session = await MilkRedemptionDemo.openFamily();
    await MilkFamilyStore.save([b]);
    await expectLater(
      MilkRedemptionDemo.redeem(session, 'FAMILY-${a.id}', '鮮奶'),
      throwsStateError,
    );
    final c = _child('c' * 32, '小晴');
    final edit = MilkFamilyStore.save([b, c]);
    final collect = MilkRedemptionDemo.redeem(session, 'FAMILY-${b.id}', '豆漿');
    await edit;
    await collect;
    final latest = await MilkFamilyStore.load();
    expect(latest.map((child) => child.id), [b.id, c.id]);
    expect(latest.last.toJson(), c.toJson());
  });

  test(
    'no family bootstrap and child role cannot mutate parent collection',
    () async {
      expect((await MilkRedemptionDemo.openFamily()).children, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MilkFamilyStore.key), isNull);
      await prefs.setString('milk_sync_child_token', 'child-sentinel');
      await expectLater(MilkRedemptionDemo.openFamily(), throwsStateError);
    },
  );
}
