import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/page/city_service/milk_route_view.dart';
import 'package:town_pass/service/milk_family_store.dart';

void main() {
  testWidgets('uses selected school and searches home without coordinates', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      MilkFamilyStore.key: jsonEncode([
        {'id': 'a', 'number': '1', 'name': '小明', 'school': '臺北信義國小'},
      ]),
      MilkFamilyStore.selectedKey: 'a',
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('townpass/place_search'),
      (call) async => [
        {
          'name': call.arguments['query'].toString().contains('臺北信義國小')
              ? '台北信義國小'
              : '家',
          'address': '台北',
          'latitude': 25.03,
          'longitude': call.arguments['query'].toString().contains('臺北信義國小')
              ? 121.55
              : 121.57,
        },
      ],
    );
    var storeSearches = 0;
    messenger.setMockMethodCallHandler(
      const MethodChannel('townpass/store_search'),
      (_) async {
        storeSearches++;
        return [];
      },
    );
    await tester.pumpWidget(const MaterialApp(home: MilkRouteView()));
    await tester.pumpAndSettle();
    expect(find.text('學校：臺北信義國小'), findsOneWidget);
    expect(find.text('輸入位置（經緯度）'), findsNothing);
    await tester.tap(find.text('搜尋回家位置'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '台北地址');
    await tester.tap(find.text('搜尋'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('家'));
    await tester.pumpAndSettle();
    expect(storeSearches, 3);
    messenger.setMockMethodCallHandler(
      const MethodChannel('townpass/place_search'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('townpass/store_search'),
      null,
    );
  });
}
