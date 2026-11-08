import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/page/city_service/milk_service_view.dart';
import 'package:town_pass/page/main/milk_daily_notice.dart';
import 'package:town_pass/service/milk_family_store.dart';

void main() {
  test('recognizes grouped card numbers while preserving leading zeros', () {
    expect(
      findCardNumber(['123456', '0123 4567 8901 2345']),
      '0123456789012345',
    );
    expect(findCardNumber(['123456']), isNull);
  });
  test('Taipei week starts on Monday', () {
    expect(weekKey(DateTime.utc(2026, 11, 8)), '2026-11-02');
    expect(weekKey(DateTime.utc(2026, 11, 9)), '2026-11-09');
  });
  testWidgets('empty home keeps secondary entry points inside Start Setup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: MilkServiceView()));
    await tester.pumpAndSettle();
    expect(find.text('我是孩子，輸入邀請碼'), findsNothing);
    expect(find.text('先看看放學順路門市'), findsNothing);
    await tester.tap(find.text('開始設定'));
    await tester.pumpAndSettle();
    expect(find.text('設定孩子資料'), findsOneWidget);
    expect(find.text('我是孩子，輸入邀請碼'), findsOneWidget);
    expect(find.text('先看看放學順路門市'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets(
    'recorded pickup remains an actionable full-size button below store search',
    (tester) async {
      final now = taipeiNow();
      SharedPreferences.setMockInitialValues({
        MilkFamilyStore.key: jsonEncode([
          {
            'id': 'a' * 32,
            'number': '0000000000000000',
            'name': '測試孩子',
            'school': '測試學校',
            'records': [
              {
                'week': weekKey(now),
                'product': '豆漿',
                'date': '2026/11/08 06:00',
              },
            ],
          },
        ]),
      });
      await tester.pumpWidget(const MaterialApp(home: MilkServiceView()));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(OutlinedButton, '查看本週領取紀錄');
      expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
      expect(
        tester.getTopLeft(button).dy,
        greaterThan(tester.getTopLeft(find.text('找附近門市')).dy),
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('本週領取紀錄'), findsOneWidget);
      expect(find.text('這筆領取紀錄已儲存，也已收進孩子的鮮奶護照。'), findsOneWidget);
      await tester.tap(find.text('關閉'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('validates the card and selects a district and school', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: MilkServiceView()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('開始設定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('設定孩子資料'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手動輸入卡號'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123');
    await tester.pump();
    expect(find.textContaining('目前輸入 3 位'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '0123456789012345');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中正區').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('請選擇學校'));
    await tester.tap(find.text('請選擇學校'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '螢橋國民小學');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('螢橋國民小學').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('確認並完成設定'));
    await tester.tap(find.text('確認並完成設定'));
    await tester.pumpAndSettle();
    expect(find.textContaining('0123456789012345'), findsNothing);
    expect(find.textContaining('螢橋國民小學'), findsOneWidget);
    await tester.ensureVisible(find.text('我已領取，留下紀錄'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我已領取，留下紀錄'));
    await tester.pumpAndSettle();
    expect(find.text('選擇附近門市'), findsNothing);
    await tester.tap(find.text('豆漿'));
    await tester.tap(find.text('我已經拿到了'));
    await tester.pumpAndSettle();
    expect(find.text('本週已記錄'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('map search displays a real returned result', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('townpass/store_search'),
          (call) async => [
            {
              'name': '全家便利商店 測試門市',
              'address': '臺北市信義區',
              'latitude': 25.0375,
              'longitude': 121.5645,
            },
          ],
        );
    await tester.pumpWidget(const MaterialApp(home: MilkStoresView()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('全家便利商店 測試門市'), findsOneWidget);
    await tester.ensureVisible(find.text('全家便利商店 測試門市'));
    await tester.pump();
    await tester.tap(find.text('全家便利商店 測試門市'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('使用 Apple 地圖導航'), findsOneWidget);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('townpass/store_search'),
          null,
        );
  });
  testWidgets(
    'daily notice stays closed after acknowledgement until the next day',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(
          home: MilkDailyNotice(child: Scaffold(body: Text('首頁'))),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('鮮奶週週報到！'), findsOneWidget);
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();
      expect(find.text('鮮奶週週報到！'), findsNothing);
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pumpWidget(
        const MaterialApp(
          home: MilkDailyNotice(child: Scaffold(body: Text('首頁'))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('鮮奶週週報到！'), findsNothing);
    },
  );
  testWidgets(
    'parent switches between children with independent weekly status',
    (tester) async {
      final now = taipeiNow();
      final data = [
        {
          'id': 'a' * 32,
          'number': '0123456789012345',
          'name': '小明',
          'school': '中正國小',
          'records': <Object>[],
        },
        {
          'id': 'b' * 32,
          'number': '1234567890123456',
          'name': '小美',
          'school': '大同國小',
          'records': [
            {'week': weekKey(now), 'product': '豆漿', 'date': '2026/11/08 09:00'},
          ],
        },
      ];
      SharedPreferences.setMockInitialValues({
        MilkFamilyStore.key: jsonEncode(data),
      });
      await tester.pumpWidget(const MaterialApp(home: MilkServiceView()));
      await tester.pumpAndSettle();
      expect(find.text('每週 1 瓶'), findsOneWidget);
      await tester.tap(find.byKey(const Key('milk-child-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('小美').last);
      await tester.pumpAndSettle();
      expect(find.text('本週已記錄'), findsOneWidget);
      expect(find.text('大同國小'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
