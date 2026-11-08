import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/page/city_service/milk_service_view.dart';
import 'package:town_pass/page/home/widget/milk_promotion_card.dart';

void main() {
  testWidgets('home promotion opens the milk feature directly', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: MilkPromotionCard())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('生生喝鮮奶'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('查看本週狀態'));
    await tester.pumpAndSettle();
    expect(find.byType(MilkServiceView), findsOneWidget);
    expect(find.text('開始設定'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('promotion remains readable on a narrow screen with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(child: MilkPromotionCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('查看本週狀態'));
    expect(tester.takeException(), isNull);
    final action = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(action.onPressed, isNotNull);
  });
}
