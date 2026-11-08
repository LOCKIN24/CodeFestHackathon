import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/page/city_service/milk_passport_view.dart';
import 'package:town_pass/page/city_service/milk_service_view.dart';
import 'package:town_pass/service/milk_family_store.dart';
import 'package:town_pass/util/milk_feature_theme.dart';

final _records = <Map<String, dynamic>>[
  {'week': '2026-11-02', 'date': '2026/11/08 10:00', 'product': '豆漿'},
  {'week': '2026-10-19', 'date': '2026/10/20 10:00', 'product': '鮮奶'},
];

void main() {
  for (final dark in [false, true]) {
    testWidgets('native passport entry is lazy and readable, dark=$dark', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: MilkFeatureTheme(
            child: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
                child: SingleChildScrollView(
                  child: MilkPassportCard(records: _records),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('已收藏 2 枚印章'), findsOneWidget);
      expect(find.text('重播蓋章'), findsOneWidget);
      expect(find.byType(InAppWebView), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an empty passport has no artificial stamps or replay action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MilkPassportCard(records: [], isDemo: true)),
      ),
    );
    expect(find.text('我的鮮奶護照'), findsOneWidget);
    expect(find.text('已收藏 0 枚印章'), findsOneWidget);
    expect(find.text('重播蓋章'), findsNothing);
    expect(find.byType(InAppWebView), findsNothing);
  });

  testWidgets(
    'weekly and trip tabs separate content and preserve selected child passport',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        MilkFamilyStore.key: jsonEncode([
          {
            'id': 'a' * 32,
            'number': '0000000000000000',
            'name': '孩子甲',
            'school': '學校',
            'records': _records,
          },
          {
            'id': 'b' * 32,
            'number': '0000000000000001',
            'name': '孩子乙',
            'school': '學校',
            'records': [],
          },
        ]),
      });
      await tester.pumpWidget(const MaterialApp(home: MilkServiceView()));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MilkPassportCard>(find.byType(MilkPassportCard))
            .records
            .length,
        2,
      );
      expect(find.text('一起去領'), findsNothing);
      await tester.tap(find.text('一起出發'));
      await tester.pumpAndSettle();
      expect(find.text('一起去領'), findsOneWidget);
      expect(find.text('放學順路領'), findsOneWidget);
      expect(find.byType(MilkPassportCard), findsNothing);
      await tester.tap(find.text('本週狀態'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('我的鮮奶護照')).dy,
        lessThan(tester.getTopLeft(find.text('領取紀錄')).dy),
      );
      await tester.tap(find.byKey(const Key('milk-child-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('孩子乙').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<MilkPassportCard>(find.byType(MilkPassportCard)).records,
        isEmpty,
      );
      expect(find.text('已收藏 0 枚印章'), findsOneWidget);
      expect(find.byType(InAppWebView), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
