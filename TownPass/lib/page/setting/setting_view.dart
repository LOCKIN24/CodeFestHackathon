import 'package:town_pass/service/local_persistence.dart';
import 'package:town_pass/page/setting/setting_view_controller.dart';
import 'package:town_pass/util/tp_setting_list.dart';
import 'package:town_pass/util/extension/datetime.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_bottom_sheet.dart';
import 'package:town_pass/util/tp_button.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:town_pass/util/tp_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingView extends GetView<SettingViewController> {
  const SettingView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder(
      init: Get.put<SettingViewController>(SettingViewController()),
      builder: (controller) {
        return Scaffold(
          appBar: const TPAppBar(title: '設定'),
          body: TPSettingList(
            children: [
              TPSettingListTile.header(title: '個人資料'),
              TPSettingListTile.navigate(
                title: '基本資料',
                onTap: () => Get.toNamed(TPRoute.basicInfo),
              ),
              TPSettingListTile.line(),
              TPSettingListTile.navigate(
                title: '語言',
                onTap: () => Get.toNamed(TPRoute.language),
              ),
              TPSettingListTile.header(title: '偏好設定'),
              TPSettingListTile.navigate(
                title: 'APP起始頁面',
                onTap: () => Get.toNamed(TPRoute.settingStartPage),
              ),
              TPSettingListTile.header(title: '通知'),
              TPSettingListTile.switchButton(
                title: '訊息通知提醒',
                controller: controller.notificationSwitch,
              ),
              TPSettingListTile.header(title: '發票設定'),
              TPSettingListTile.navigate(
                title: '手機載具',
                onTap: () => Get.toNamed(TPRoute.invoiceReceipt),
              ),
              TPSettingListTile.header(title: '安全性'),
              TPSettingListTile.navigate(
                title: '歷程與授權管理',
                onTap: () => Get.toNamed(TPRoute.portfolioAndAuth),
              ),
              TPSettingListTile.line(),
              TPSettingListTile.switchButton(
                title: '快速登入',
                controller: controller.quickLoginSwitch,
              ),
              TPSettingListTile.line(),
              TPSettingListTile.navigate(
                title: '停用帳號',
                onTap: () => Get.toNamed(TPRoute.suspendAccount),
              ),
            ],
          ),
          bottomNavigationBar: TPBottomSheet(
            child: Column(
              children: [
                TPText(
                  '最後登入時間：${controller.lastLoginDateTime.format('yyyy/MM/dd HH:mm:ss')}',
                  style: TPTextStyles.bodyRegular,
                  color: TPColors.primary500,
                ),
                const SizedBox(height: 10),
                TPButton.primary(
                  text: '登出',
                  onPressed: () async {
                    final yes = await showDialog<bool>(
                      context: context,
                      builder: (dialog) => AlertDialog(
                        backgroundColor: TPColors.white,
                        title: const Text('登出城市通？'),
                        content: const Text('這台手機儲存的資料會保留。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialog, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialog, true),
                            child: const Text('登出'),
                          ),
                        ],
                      ),
                    );
                    if (yes != true) return;
                    try {
                      await LocalPersistence.flag('local_signed_out', true);
                    } catch (_) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('設定未能儲存，請稍後重試。')),
                        );
                      return;
                    }
                    Get.offAllNamed(TPRoute.main);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
