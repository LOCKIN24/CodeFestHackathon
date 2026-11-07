import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get/get.dart';
import 'package:town_pass/main.dart' as app;
import 'package:town_pass/page/main/main_view_controller.dart';
import 'package:town_pass/page/home/widget/activity_info/activity_banner_widget_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('automatic real navigation and unsafe requests', (tester) async {
    app.main();
    await tester.pump(const Duration(seconds: 3));
    for (
      var i = 0;
      i < 20 &&
          (!Get.isRegistered<ActivityBannerWidgetController>() ||
              Get.find<ActivityBannerWidgetController>().list == null);
      i++
    ) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(Get.find<ActivityBannerWidgetController>().list, isNotNull);
    await tester.tap(find.byKey(const Key('navigation-tab-2')));
    await tester.pump(const Duration(seconds: 1));
    expect(Get.find<MainViewController>().currentIndex.value, 2);
    Future<void> ask(String query) async {
      await tester.tap(find.byKey(const Key('assistant-launcher')));
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.byKey(const Key('assistant-input')), query);
      await tester.tap(find.byKey(const Key('assistant-send')));
    }

    await ask('帶我去語言設定');
    for (var i = 0; i < 40 && find.text('繁體中文').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('繁體中文'), findsOneWidget);
    expect(find.byKey(const Key('assistant-sheet')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    debugPrint('SIMULATOR_LANGUAGE_SCREEN');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 5)),
    );
    await tester.pageBack();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(Get.find<MainViewController>().currentIndex.value, 2);
    await ask('我要看活動訊息');
    final firstTitle =
        Get.find<ActivityBannerWidgetController>().list!.data.first.title;
    for (var i = 0; i < 40 && find.text(firstTitle).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text(firstTitle), findsWidgets);
    expect(find.byKey(const Key('assistant-sheet')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    debugPrint('SIMULATOR_ACTIVITY_SCREEN');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 20)),
    );
    await tester.pageBack();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(Get.find<MainViewController>().currentIndex.value, 2);
    for (final query in [
      '請幫我完成付款',
      '我要查空氣品質',
      '我要看股票價格',
      '我要查看票夾並購買票券',
      '我要看活動詳情',
    ]) {
      await ask(query);
      final expected = query.contains('付款') || query.contains('購買')
          ? '抱歉，我無法代替你執行付款、購買或其他服務操作。'
          : query.contains('詳情')
          ? '目前無法直接開啟這個活動詳情，請先選擇活動。'
          : '我無法確認你要找的頁面，請換個方式描述。';
      for (var i = 0; i < 20 && find.text(expected).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text(expected), findsOneWidget, reason: query);
      debugPrint('BLOCKED_REQUEST $query');
      expect(
        find.byKey(const Key('assistant-sheet')),
        findsOneWidget,
        reason: query,
      );
      expect(Get.currentRoute, '/', reason: query);
      expect(
        find.byKey(const Key('assistant-destination')),
        findsNothing,
        reason: query,
      );
      await tester.drag(
        find.byKey(const Key('assistant-sheet-handle')),
        const Offset(0, 500),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      if (find.byKey(const Key('assistant-sheet')).evaluate().isNotEmpty) {
        await tester.drag(
          find.byKey(const Key('assistant-sheet-handle')),
          const Offset(0, 500),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }
      expect(find.byKey(const Key('assistant-sheet')), findsNothing);
      expect(Get.find<MainViewController>().currentIndex.value, 2);
    }
  });
}
