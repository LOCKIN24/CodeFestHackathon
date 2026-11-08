import 'package:town_pass/service/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:town_pass/bean/subscription.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_text.dart';

class SubscriptionView extends StatelessWidget {
  SubscriptionItem? get subscription => Get.arguments is SubscriptionItem
      ? Get.arguments as SubscriptionItem
      : null;

  const SubscriptionView({super.key});

  @override
  Widget build(BuildContext context) {
    final item = subscription;
    if (item == null) {
      final service = Get.find<SubscriptionService>();
      return Scaffold(
        appBar: const TPAppBar(title: '我的訂閱'),
        backgroundColor: TPColors.white,
        body: Obx(
          () => service.itemList.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('目前沒有訂閱內容。可從首頁選擇感興趣的服務。'),
                  ),
                )
              : ListView(
                  children: [
                    for (final value in service.itemList)
                      ListTile(
                        title: Text(value.title),
                        subtitle: Text(
                          DateFormat('yyyy/MM/dd').format(value.datetime),
                        ),
                        onTap: () =>
                            Get.toNamed('/subscription', arguments: value),
                      ),
                  ],
                ),
        ),
      );
    }
    return Scaffold(
      appBar: const TPAppBar(title: '訂閱'),
      backgroundColor: TPColors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TPText(item.title, style: TPTextStyles.titleSemiBold),
              const SizedBox(height: 12.0),
              TPText(item.content, style: TPTextStyles.bodyRegular),
              const SizedBox(height: 16.0),
              TPText(
                DateFormat('yyyy/MM/dd').format(item.datetime),
                style: TPTextStyles.bodyRegular,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
