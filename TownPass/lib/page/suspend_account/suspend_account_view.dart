import 'package:town_pass/page/local_service/local_service_view.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:town_pass/gen/assets.gen.dart';
import 'package:town_pass/page/suspend_account/suspend_account_controller.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_button.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_constant.dart';
import 'package:town_pass/util/tp_setting_list.dart';
import 'package:town_pass/util/tp_text.dart';
import 'package:url_launcher/url_launcher.dart';

class SuspendAccountView extends GetView<SuspendAccountController> {
  const SuspendAccountView({super.key});

  /// 內部共用方法：開啟郵件應用程式至客服信箱。
  /// 此方法將郵件連結的建構與錯誤處理邏輯封裝起來，避免在 Widget tree 中直接寫入。
  /// 如果無法開啟郵件應用程式，則會顯示一個 Toast 提示。
  Future<void> _launchCustomerServiceMail() async {
    final Uri uri = Uri(scheme: tpLaunchMailScheme, path: tpMailAddress);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Fluttertoast.showToast(msg: '無法開啟郵件 App');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TPAppBar(title: '停用帳號'),
      body: TPSettingList(
        children: [
          TPSettingListTile.header(title: '目前登入帳號'),
          TPSettingListTile.listTile(
            leading: Assets.svg.iconPerson.svg(),
            title: TPText(
              controller.name,
              style: TPTextStyles.h2Regular,
              color: TPColors.grayscale800,
            ),
          ),
          TPSettingListTile.line(),
          TPSettingListTile.listTile(
            leading: Assets.svg.iconIdCard.svg(),
            title: TPText(
              controller.idNumber,
              style: TPTextStyles.h2Regular,
              color: TPColors.grayscale800,
            ),
          ),
          TPSettingListTile.line(),
          TPSettingListTile(
            backgroundColor: TPColors.white,
            child: Column(
              children: [
                const TPText(
                  '提出停用申請後，可在使用紀錄查看申請內容。處理完成前，你仍可使用目前的帳號。',
                  style: TPTextStyles.bodyRegular,
                  color: TPColors.black,
                ),
                const SizedBox(height: 16),
                TPButton.primary(
                  text: '提出停用申請',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialog) => AlertDialog(
                        backgroundColor: TPColors.white,
                        title: const Text('提出停用申請？'),
                        content: const Text('確認後會儲存這筆申請，現有資料不會立即刪除。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialog, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialog, true),
                            child: const Text('確認申請'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    await LocalServiceStore.save('帳號停用', '停用申請已儲存');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('停用申請已儲存，可在使用紀錄查看。')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          TPSettingListTile.header(title: '帳號復用方式'),
          TPSettingListTile.listTile(
            backgroundColor: TPColors.transparent,
            leading: Assets.svg.iconLogout.svg(),
            title: const TPText(
              '登入台北通，需重新驗證您的手機或Email資料來復用帳號',
              style: TPTextStyles.bodyRegular,
              color: TPColors.grayscale800,
            ),
          ),
          TPSettingListTile.listTile(
            backgroundColor: TPColors.transparent,
            leading: Assets.svg.iconMail.svg(),
            title: const TPText(
              '客服信箱',
              style: TPTextStyles.bodyRegular,
              color: TPColors.grayscale800,
            ),
            subtitle: TPText(
              tpMailAddress,
              style: TPTextStyles.bodyRegular.copyWith(
                color: TPColors.primary500,
                decoration: TextDecoration.underline,
                decorationColor: TPColors.primary500,
              ),
              onTap: _launchCustomerServiceMail, // 改為呼叫新建立的私有方法
            ),
          ),
        ],
      ),
    );
  }
}
