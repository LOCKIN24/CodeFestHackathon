import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/service/milk_family_store.dart';

void main() {
  MilkChild child(String id) => MilkChild(
    id: id,
    number: '0123456789012345',
    name: '測試孩子',
    school: '測試學校',
    records: [
      {
        'week': '2026-11-02',
        'product': '豆漿',
        'date': '2026/11/08',
        'store': '本機門市紀錄',
      },
    ],
  );

  test(
    'outing merge observes a queued family change and preserves local metadata',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = child('a' * 32), sibling = child('b' * 32);
      await MilkFamilyStore.save([first]);
      final save = MilkFamilyStore.save([first, sibling]);
      final merge = MilkFamilyStore.mergeOuting(first.id, {
        'status': 'planned',
        'revision': 2,
      });
      await save;
      final result = await merge;
      expect(result.map((c) => c.id), [first.id, sibling.id]);
      expect(result.first.records.single['store'], '本機門市紀錄');
      expect(result.first.outing!['revision'], 2);
      expect(result.last.outing, isNull);
      expect((await MilkFamilyStore.load()).length, 2);
    },
  );

  test(
    'outing response cannot recreate a child removed on another screen',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = child('a' * 32), sibling = child('b' * 32);
      await MilkFamilyStore.save([first, sibling]);
      final removal = MilkFamilyStore.save([sibling]);
      final merge = MilkFamilyStore.mergeOuting(first.id, {
        'status': 'planned',
        'revision': 2,
      });
      await removal;
      expect((await merge).single.id, sibling.id);
      expect((await MilkFamilyStore.load()).single.id, sibling.id);
    },
  );

  test('migrates the original child once and keeps records', () async {
    SharedPreferences.setMockInitialValues({
      MilkFamilyStore.legacyKey: jsonEncode({
        'number': '0123456789012345',
        'name': '孩子',
        'school': '學校',
        'records': [
          {'week': '2026-11-02', 'product': '鮮奶', 'date': '2026/11/04'},
        ],
      }),
    });
    final both = await Future.wait([
      MilkFamilyStore.load(),
      MilkFamilyStore.load(),
    ]);
    expect(both.first.single.id, both.last.single.id);
    expect(both.first.single.number, '0123456789012345');
    expect(both.first.single.records.single['week'], '2026-11-02');
    final second = MilkChild(
      id: MilkChild.newId(),
      number: '1234567890123456',
      name: '另一位',
      school: '學校',
    );
    await MilkFamilyStore.save([both.first.single, second]);
    final loaded = await MilkFamilyStore.load();
    expect(loaded.length, 2);
    expect(loaded.first.records.length, 1);
    expect(loaded.last.records, isEmpty);
  });
}
