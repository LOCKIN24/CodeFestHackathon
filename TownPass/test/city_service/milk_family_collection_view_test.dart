import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/page/city_service/milk_redemption_demo_view.dart';
import 'package:town_pass/service/milk_family_store.dart';
import 'package:town_pass/service/milk_passport.dart';

void main() {
  testWidgets(
    'collection uses selected parent child and persists the same passport without a URL',
    (tester) async {
      final a = MilkChild(
        id: 'a' * 32,
        number: '0000000000000001',
        name: '孩子甲',
        school: '測試學校',
      );
      final b = MilkChild(
        id: 'b' * 32,
        number: '0000000000000002',
        name: '孩子乙',
        school: '測試學校',
      );
      SharedPreferences.setMockInitialValues({
        MilkFamilyStore.key: jsonEncode([a.toJson(), b.toJson()]),
      });
      await tester.binding.setSurfaceSize(const Size(440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MilkRedemptionDemoView(familyMode: true, reminderChildId: b.id),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(find.byKey(ValueKey('demo-child-${b.id}')))
            .properties
            .checked,
        isTrue,
      );
      expect(find.byType(TextField), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('demo-drink-豆漿')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('demo-drink-豆漿')));
      await tester.pumpAndSettle();
      final collect = find.text('領取 1 瓶豆漿');
      await tester.ensureVisible(collect);
      await tester.pumpAndSettle();
      await tester.tap(collect);
      await tester.pumpAndSettle();
      final family = await MilkFamilyStore.load();
      expect(family.first.records, isEmpty);
      expect(family.last.records.single['product'], '豆漿');
      expect(MilkPassport.fromRecords(family.last.records).count, 1);
      expect(find.widgetWithText(FilledButton, '本週已領取'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '本週已領取'))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets(
    'empty parent family offers recovery without an inert collection button',
    (tester) async {
      SharedPreferences.setMockInitialValues({MilkFamilyStore.key: '[]'});
      await tester.pumpWidget(
        const MaterialApp(home: MilkRedemptionDemoView(familyMode: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('先新增孩子，再選擇飲品。'), findsOneWidget);
      expect(find.text('返回家庭設定'), findsOneWidget);
      expect(find.textContaining('領取 1 瓶'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
