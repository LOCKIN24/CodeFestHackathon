import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/service/milk_family_store.dart';

/// One-time fictional starting data for this hackathon build. Existing accounts,
/// families, records and links are never replaced; clearing stays cleared.
class MilkShowcaseProfile {
  static const marker = 'milk_showcase_seeded_v1';
  static const enabled = bool.fromEnvironment(
    'MILK_SHOWCASE',
    defaultValue: true,
  );
  static Future<void> initialize() async {
    if (!enabled) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(marker) == true) return;
    if (prefs.containsKey(MilkFamilyStore.key) ||
        prefs.containsKey(MilkFamilyStore.legacyKey)) {
      await prefs.setBool(marker, true);
      return;
    }
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final monday = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    Map<String, dynamic> previous(int weeks, String product) {
      final week = monday.subtract(Duration(days: 7 * weeks));
      final date = week.add(const Duration(days: 1));
      return {
        'week': week.toIso8601String().substring(0, 10),
        'product': product,
        'date':
            '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} 16:00',
      };
    }

    final children = [
      MilkChild(
        id: MilkChild.newId(),
        number: '0000000000000001',
        name: '小明',
        school: '信義國小',
        records: [previous(1, '豆漿'), previous(3, '鮮奶')],
      ),
      MilkChild(
        id: MilkChild.newId(),
        number: '0000000000000002',
        name: '小安',
        school: '信義國小',
      ),
    ];
    await MilkFamilyStore.save(children);
    await prefs.setString(MilkFamilyStore.selectedKey, children.first.id);
    await prefs.setBool(marker, true);
  }
}
