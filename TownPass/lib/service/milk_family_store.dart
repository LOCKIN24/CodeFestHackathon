import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Data stored locally for the hackathon; the server never receives card numbers.
class MilkChild {
  MilkChild({
    required this.id,
    required this.number,
    required this.name,
    required this.school,
    this.records = const [],
    this.outing,
  });
  final String id, number, name, school;
  final List<Map<String, dynamic>> records;
  final Map<String, dynamic>? outing;

  static String newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'name': name,
    'school': school,
    'records': records,
    if (outing != null) 'outing': outing,
  };
  factory MilkChild.fromJson(Map<String, dynamic> json) => MilkChild(
    id: json['id'] as String? ?? newId(),
    number: json['number'] as String,
    name: json['name'] as String,
    school: json['school'] as String,
    records: (json['records'] as List? ?? [])
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList(),
    outing: json['outing'] is Map
        ? Map<String, dynamic>.from(json['outing'] as Map)
        : null,
  );
}

class MilkFamilyStore {
  static const key = 'milk_family_v2';
  static const legacyKey = 'milk_demo_v1';
  static const selectedKey = 'milk_selected_child_v2';
  static Future<List<MilkChild>>? _pendingLoad;
  static Future<void> _writes = Future.value();
  static int _pendingWrites = 0;

  static Future<List<MilkChild>> load() async {
    // A reminder can open another detail route while a save is finishing.
    // Readers must observe queued writes before reloading the family.
    if (_pendingWrites > 0) await _writes.catchError((Object _) {});
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw != null) {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map(
            (child) =>
                MilkChild.fromJson(Map<String, dynamic>.from(child as Map)),
          )
          .toList();
    }
    final legacy = prefs.getString(legacyKey);
    if (legacy == null) return [];
    // Only migration needs coalescing to give concurrent readers the same ID.
    // Ordinary reads must observe the latest stored family, not another route's
    // in-flight snapshot.
    final existing = _pendingLoad;
    if (existing != null) return existing;
    final task = _migrate(legacy);
    _pendingLoad = task;
    try {
      return await task;
    } finally {
      if (identical(_pendingLoad, task)) _pendingLoad = null;
    }
  }

  static Future<List<MilkChild>> _migrate(String legacy) async {
    final child = MilkChild.fromJson(
      jsonDecode(legacy) as Map<String, dynamic>,
    );
    await save([child]);
    return [child];
  }

  static Future<void> save(List<MilkChild> children) {
    final payload = jsonEncode(
      children.map((child) => child.toJson()).toList(),
    );
    _pendingWrites++;
    final next = _writes.catchError((Object _) {}).then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(key, payload)) throw StateError('無法儲存學生資料');
      } finally {
        _pendingWrites--;
      }
    });
    _writes = next;
    return next;
  }

  static Future<void> clear() async {
    await _writes.catchError((Object _) {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove(legacyKey);
    await prefs.remove(selectedKey);
  }

  /// Apply one fake POS event against the latest family, on the same write
  /// queue used by edits and removals. The external provider never sees cards.
  static Future<({String result, MilkChild child})> recordDemoPickup(
    String childId,
    Map<String, dynamic> record,
  ) {
    final event = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(record)) as Map,
    );
    _pendingWrites++;
    final next = _writes.catchError((Object _) {}).then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final previous = prefs.getString(key);
        final family =
            (previous == null ? <dynamic>[] : jsonDecode(previous) as List)
                .map(
                  (item) => MilkChild.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList();
        final index = family.indexWhere((child) => child.id == childId);
        if (index < 0) throw StateError('這位孩子已移除，請重新開啟。');
        final child = family[index];
        if (child.records.any(
          (r) => r['transactionId'] == event['transactionId'],
        )) {
          return (result: 'duplicate_transaction', child: child);
        }
        if (child.records.any((r) => r['week'] == event['week'])) {
          return (result: 'already_recorded', child: child);
        }
        var outing = child.outing;
        if (outing != null &&
            outing['week'] == event['week'] &&
            const ['requested', 'planned'].contains(outing['status'])) {
          outing = {
            ...outing,
            'status': 'completed',
            'revision': (outing['revision'] as int? ?? 0) + 1,
            'updatedAt': event['confirmedAt'],
          };
        }
        final updated = MilkChild.fromJson({
          ...child.toJson(),
          'records': [event, ...child.records],
          'outing': outing,
        });
        family[index] = updated;
        var stored = false;
        try {
          stored = await prefs.setString(
            key,
            jsonEncode(family.map((c) => c.toJson()).toList()),
          );
        } catch (_) {}
        if (!stored) {
          try {
            if (previous == null) {
              await prefs.remove(key);
            } else {
              await prefs.setString(key, previous);
            }
          } catch (_) {}
          throw StateError('無法儲存領取紀錄，請重試。');
        }
        return (result: 'accepted', child: updated);
      } finally {
        _pendingWrites--;
      }
    });
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  /// Commit only this child's server-confirmed plan against the latest family.
  /// A notification may have opened a newer screen while the plan form was up.
  static Future<List<MilkChild>> mergeOuting(
    String childId,
    Map<String, dynamic>? outing,
  ) {
    _pendingWrites++;
    final next = _writes.catchError((Object _) {}).then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(key);
        final latest = (raw == null ? <dynamic>[] : jsonDecode(raw) as List)
            .map(
              (item) =>
                  MilkChild.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
        final index = latest.indexWhere((child) => child.id == childId);
        if (index < 0) return latest;
        latest[index] = MilkChild.fromJson({
          ...latest[index].toJson(),
          'outing': outing,
        });
        if (!await prefs.setString(
          key,
          jsonEncode(latest.map((c) => c.toJson()).toList()),
        )) {
          throw StateError('無法儲存家庭行程');
        }
        return latest;
      } finally {
        _pendingWrites--;
      }
    });
    // The caller observes failures; the queue must remain usable afterwards.
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
