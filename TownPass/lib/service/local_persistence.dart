import 'package:shared_preferences/shared_preferences.dart';

/// A rejected platform write must not appear as a successful local action.
/// Reload also discards the preferences plugin's optimistic memory cache.
class LocalPersistence {
  static Future<void> flag(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await checked(prefs, prefs.setBool(key, value));
  }

  static Future<void> checked(
    SharedPreferences prefs,
    Future<bool> write,
  ) async {
    try {
      if (await write) return;
    } catch (_) {
      try {
        await prefs.reload();
      } catch (_) {}
      rethrow;
    }
    try {
      await prefs.reload();
    } catch (_) {}
    throw StateError('無法儲存，請稍後重試。');
  }
}
