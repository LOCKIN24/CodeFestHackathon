import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/page/main/main_view_controller.dart';
import 'package:town_pass/page/main/milk_daily_notice.dart';
import 'package:town_pass/page/main/assistant_bottom_navigation.dart';
import 'package:town_pass/page/ai_assistant/assistant_sheet.dart';
import 'package:town_pass/util/tp_bottom_navigation_factory.dart';

class MainView extends GetView<MainViewController> {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) {
    return MilkDailyNotice(
      child: Obx(
        () => TickerMode(
          enabled: !controller.assistantVisible.value,
          child: Scaffold(
            body: Obx(
              () => IndexedStack(
                index: controller.currentIndex.value,
                children: TPBottomNavigationFactory.viewList,
              ),
            ),
            bottomNavigationBar: Obx(
              () => AssistantBottomNavigation(
                currentIndex: controller.currentIndex.value,
                onSelect: (index) => controller.currentIndex.value = index,
                openAssistant: () async {
                  controller.assistantVisible.value = true;
                  try {
                    await showAssistantSheet(context);
                  } finally {
                    controller.assistantVisible.value = false;
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
