import 'package:town_pass/service/local_persistence.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Language { traditionalChinese, english }

class LanguageViewController extends GetxController {
  static const preferenceKey = 'preferred_language';
  final selectedIndex = 0.obs;
  List<Language> get languageList => Language.values;
  @override
  void onInit() {
    super.onInit();
    loadPreference();
  }

  Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    selectedIndex.value = prefs.getString(preferenceKey) == 'en' ? 1 : 0;
  }

  Future<void> onIndexChange(int index) async {
    if (index < 0 || index >= languageList.length) return;
    final code = index == 1 ? 'en' : 'zh';
    final prefs = await SharedPreferences.getInstance();
    try {
      await LocalPersistence.checked(
        prefs,
        prefs.setString(preferenceKey, code),
      );
    } catch (_) {
      if (Get.context != null) {
        Get.snackbar('儲存失敗', '請稍後再試。');
      }
      return;
    }
    selectedIndex.value = index;
    await Get.updateLocale(Locale(code, code == 'en' ? 'US' : 'TW'));
  }
}
