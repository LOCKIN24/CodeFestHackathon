import 'package:town_pass/service/local_persistence.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/service/milk_reminder_service.dart';
import 'package:town_pass/util/tp_switch.dart';

class SettingViewController extends GetxController {
  late final notificationSwitch = TPSwitchController(
    true,
    onChanged: (value) => _save('notifications_enabled', value),
  );
  late final quickLoginSwitch = TPSwitchController(
    true,
    onChanged: (value) => _save('quick_login_enabled', value),
  );
  @override
  void onInit() {
    super.onInit();
    loadPreferences();
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    notificationSwitch.value.value =
        prefs.getBool('notifications_enabled') ?? true;
    quickLoginSwitch.value.value = prefs.getBool('quick_login_enabled') ?? true;
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await LocalPersistence.checked(prefs, prefs.setBool(key, value));
      if (key == 'notifications_enabled') await MilkReminderService.refresh();
    } catch (_) {
      await loadPreferences();
      if (Get.context != null) {
        Get.snackbar('儲存失敗', '原有設定已保留，請稍後再試。');
      }
    }
  }

  bool get isNotificationOn => notificationSwitch.value.value;
  set isNotificationOn(bool value) {
    notificationSwitch.value.value = value;
    _save('notifications_enabled', value);
  }

  bool get isBioAuthOn => quickLoginSwitch.value.value;
  set isBioAuthOn(bool value) {
    quickLoginSwitch.value.value = value;
    _save('quick_login_enabled', value);
  }

  DateTime get lastLoginDateTime => DateTime.now();
}
