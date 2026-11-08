import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/page/city_service/milk_service_view.dart';
import 'package:town_pass/service/milk_family_store.dart';

void main() {
  testWidgets(
    'child card labels full selected name and school and switches by id',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const firstName = '測試孩子完整姓名';
      const firstSchool = '臺北市測試非營利幼兒園附設長名稱分班';
      SharedPreferences.setMockInitialValues({
        MilkFamilyStore.key: jsonEncode([
          {
            'id': 'a' * 32,
            'number': '0000000000000001',
            'name': firstName,
            'school': firstSchool,
            'records': [],
          },
          {
            'id': 'b' * 32,
            'number': '0000000000000002',
            'name': '另一位孩子',
            'school': '另一所學校',
            'records': [],
          },
        ]),
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: const MilkServiceView(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('目前孩子'), findsOneWidget);
      expect(find.text('學校'), findsOneWidget);
      expect(find.text(firstSchool), findsOneWidget);
      expect(find.text(firstName), findsOneWidget);
      expect(find.text('切換'), findsOneWidget);
      expect(find.byTooltip('資格說明'), findsOneWidget);
      final selector = find.byKey(const Key('milk-child-selector'));
      expect(tester.widget<DropdownButton<String>>(selector).value, 'a' * 32);
      expect(tester.getSize(selector).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(selector);
      await tester.pumpAndSettle();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('另一位孩子').last);
      await tester.pumpAndSettle();
      expect(tester.widget<DropdownButton<String>>(selector).value, 'b' * 32);
      expect(find.text('另一所學校'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString(
          MilkFamilyStore.selectedKey,
        ),
        'b' * 32,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
