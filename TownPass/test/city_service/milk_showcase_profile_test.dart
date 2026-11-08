import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/service/milk_family_store.dart';
import 'package:town_pass/service/milk_showcase_profile.dart';

void main() {
  test('new showcase has two children and repeat startup preserves identity/history', () async {
    SharedPreferences.setMockInitialValues({});
    await MilkShowcaseProfile.initialize();
    final first = await MilkFamilyStore.load();
    expect(first.length, 2);
    expect(first.first.records.length, 2);
    expect(first.last.records, isEmpty);
    await MilkShowcaseProfile.initialize();
    expect((await MilkFamilyStore.load()).first.id, first.first.id);
  });
  test('existing family is never overwritten', () async {
    final child = MilkChild(
      id: 'a' * 32,
      number: '0000000000000000',
      name: '原本孩子',
      school: '原本學校',
    );
    SharedPreferences.setMockInitialValues({
      MilkFamilyStore.key: jsonEncode([child.toJson()]),
    });
    await MilkShowcaseProfile.initialize();
    expect((await MilkFamilyStore.load()).single.name, '原本孩子');
  });
  test('cleared family stays cleared after relaunch', () async {
    SharedPreferences.setMockInitialValues({});
    await MilkShowcaseProfile.initialize();
    await MilkFamilyStore.clear();
    await MilkShowcaseProfile.initialize();
    expect(await MilkFamilyStore.load(), isEmpty);
  });
}
