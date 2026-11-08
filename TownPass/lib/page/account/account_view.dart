import 'package:town_pass/service/local_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/gen/assets.gen.dart';
import 'package:town_pass/page/account/account_view_controller.dart';
import 'package:town_pass/page/account/widget/account_app_bar.dart';
import 'package:town_pass/page/account/widget/account_view_footer.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:town_pass/util/tp_setting_list.dart';
import 'package:town_pass/util/tp_text.dart';

class AccountView extends GetView<AccountViewController> {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: SharedPreferences.getInstance().then(
      (prefs) => prefs.getBool('local_signed_out') ?? false,
    ),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.data == true) {
        return Scaffold(
          appBar: const AccountAppBar(),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 64,
                    color: TPColors.primary700,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '歡迎使用城市通',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Text('登入後查看個人訊息、訂閱與服務紀錄。'),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await LocalPersistence.flag('local_signed_out', false);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('設定未能儲存，請稍後重試。')),
                          );
                        }
                        return;
                      }
                      Get.offAllNamed(TPRoute.main);
                    },
                    child: const Text('繼續使用城市通'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return _signedIn(context);
    },
  );

  Widget _signedIn(BuildContext context) {
    return Scaffold(
      appBar: const AccountAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Obx(
                () => TPSettingList(
                  children: [
                    TPSettingListTile.space(
                      backgroundColor: TPColors.white,
                      height: 19,
                    ),
                    TPSettingListTile.listTile(
                      excludeFromSemantics: true,
                      leading: Assets.svg.iconPerson.svg(),
                      title: TPText(
                        controller.name.value,
                        style: TPTextStyles.h2Regular,
                        color: TPColors.grayscale800,
                      ),
                      trailing: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async =>
                            await Get.toNamed(TPRoute.setting)
                                ?.then((value) => controller.syncAccount()),
                        child: Semantics(
                          label: '設定',
                          child: Assets.svg.iconSettings.svg(),
                        ),
                      ),
                    ),
                    TPSettingListTile.line(),
                    TPSettingListTile.listTile(
                      excludeFromSemantics: true,
                      leading: Assets.svg.iconPhone.svg(),
                      title: TPText(
                        controller.phoneNumber.value,
                        style: TPTextStyles.h2Regular,
                        color: TPColors.grayscale800,
                      ),
                      trailing: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async =>
                            await Get.toNamed(TPRoute.setting)
                                ?.then((value) => controller.syncAccount()),
                        child: Semantics(
                          label: '設定',
                          child: Assets.svg.iconSettings.svg(),
                        ),
                      ),
                    ),
                    TPSettingListTile.space(),
                    TPSettingListTile.navigate(
                      title: '訊息',
                      onTap: () => Get.toNamed(TPRoute.message),
                    ),
                    TPSettingListTile.line(),
                    TPSettingListTile.navigate(
                      title: '歷程與授權管理',
                      onTap: () => Get.toNamed(TPRoute.portfolioAndAuth),
                    ),
                    TPSettingListTile.line(),
                    TPSettingListTile.navigate(
                      title: '訂閱',
                      content: '管理我的訂閱',
                      onTap: () => Get.toNamed(TPRoute.subscription),
                    ),
                    TPSettingListTile.space(),
                    TPSettingListTile.navigate(
                      title: '功能教學',
                      onTap: () async => await TPRoute.openUri(
                        uri: 'https://id.taipei/tpcd/about/faq',
                      ),
                    ),
                    TPSettingListTile.line(),
                    TPSettingListTile.navigate(
                      title: '意見回饋',
                      onTap: () => Get.toNamed(TPRoute.feedback),
                    ),
                    TPSettingListTile.line(),
                    TPSettingListTile.display(
                      title: '版本',
                      content: controller.appVersion,
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: AccountViewFooter(),
            ),
          ],
        ),
      ),
    );
  }
}
