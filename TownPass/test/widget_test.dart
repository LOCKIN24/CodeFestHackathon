import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/main.dart';
import 'package:town_pass/page/city_service/milk_service_view.dart';
import 'package:town_pass/page/main/assistant_bottom_navigation.dart';
import 'package:town_pass/page/main/main_view_controller.dart';
import 'package:town_pass/page/main/milk_daily_notice.dart';
import 'package:town_pass/service/milk_family_store.dart';
import 'package:town_pass/service/shared_preferences_service.dart';
import 'package:town_pass/service/subscription_service.dart';

/// The shell still mounts the existing perks WebView in its indexed stack.
/// Stub only the native boundary; no real server or OS permission is required.
class _WebViewPlatform extends InAppWebViewPlatform {
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) => _WebView(params);
}

class _WebView extends PlatformInAppWebViewWidget {
  _WebView(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      throw UnimplementedError(
        'The shell test never creates a native controller',
      );
  @override
  void dispose() {}
}

void main() {
  testWidgets(
    'main retains assistant navigation and opens the Studio milk feature',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final previousWebView = InAppWebViewPlatform.instance;
      InAppWebViewPlatform.instance = _WebViewPlatform();
      addTearDown(() {
        if (previousWebView != null) {
          InAppWebViewPlatform.instance = previousWebView;
        }
      });
      Get.testMode = true;
      addTearDown(Get.reset);
      final today = DateTime.now().toUtc().add(const Duration(hours: 8));
      final day =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      SharedPreferences.setMockInitialValues({
        'milk_notice_ack_date': day,
        'notifications_enabled': false,
        MilkFamilyStore.key: jsonEncode([
          {
            'id': 'a' * 32,
            'number': '0000000000000001',
            'name': '測試孩子',
            'school': '測試學校',
            'records': [],
          },
        ]),
      });
      Get.put<SharedPreferencesService>(
        await SharedPreferencesService().init(),
      );
      Get.put<SubscriptionService>(SubscriptionService());
      await tester.pumpWidget(const MyApp());
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(MilkDailyNotice), findsOneWidget);
      expect(find.byType(AssistantBottomNavigation), findsOneWidget);
      expect(find.byKey(const Key('assistant-launcher')), findsOneWidget);
      expect(find.text('查看本週狀態'), findsOneWidget);
      expect(Get.find<MainViewController>().currentIndex.value, 1);

      await tester.tap(find.byKey(const Key('assistant-launcher')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('assistant-sheet')), findsOneWidget);
      expect(Get.find<MainViewController>().assistantVisible.value, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('assistant-sheet')), findsNothing);
      expect(Get.find<MainViewController>().assistantVisible.value, isFalse);

      await tester.ensureVisible(find.text('查看本週狀態'));
      await tester.pump();
      await tester.tap(find.text('查看本週狀態'));
      await tester.pump();
      for (
        var frame = 0;
        frame < 10 && find.byType(MilkServiceView).evaluate().isEmpty;
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MilkServiceView), findsOneWidget);
      expect(find.byKey(const Key('milk-section-tabs')), findsOneWidget);
      expect(find.text('測試孩子'), findsOneWidget);
      expect(Get.find<MainViewController>().currentIndex.value, 1);

      // Let existing one-shot mock feed loaders finish, then dispose carousel,
      // shimmer, route and reminder timers before the test invariant check.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
