/// Calendar helpers interpret an instant in Taipei, independent of device zone.
DateTime milkTaipeiDate(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 8));

String milkOutingWeek(DateTime instant) {
  final day = milkTaipeiDate(instant);
  return DateTime.utc(day.year, day.month, day.day)
      .subtract(Duration(days: day.weekday - 1))
      .toIso8601String()
      .substring(0, 10);
}

class MilkOuting {
  const MilkOuting({
    required this.week,
    required this.status,
    required this.revision,
    this.store,
    this.plannedAt,
  });
  final String week, status;
  final int revision;
  final Map<String, dynamic>? store;
  final DateTime? plannedAt;

  static MilkOuting? fromProfile(
    Map<String, dynamic> profile, {
    DateTime? now,
  }) {
    final raw = profile['outing'];
    if (raw is! Map || raw['week'] != milkOutingWeek(now ?? DateTime.now())) {
      return null;
    }
    if (!const [
          'requested',
          'planned',
          'canceled',
          'completed',
        ].contains(raw['status']) ||
        raw['revision'] is! int) {
      return null;
    }
    return MilkOuting(
      week: raw['week'] as String,
      status: raw['status'] as String,
      revision: raw['revision'] as int,
      store: raw['store'] is Map
          ? Map<String, dynamic>.from(raw['store'] as Map)
          : null,
      plannedAt: raw['plannedAt'] is String
          ? DateTime.tryParse(raw['plannedAt'] as String)
          : null,
    );
  }

  String get whenLabel {
    final time = plannedAt;
    if (time == null) return '';
    final day = milkTaipeiDate(time);
    return '${day.month}/${day.day}（${const ['一', '二', '三', '四', '五', '六', '日'][day.weekday - 1]}）${day.hour.toString().padLeft(2, '0')}:${day.minute.toString().padLeft(2, '0')}・台北時間';
  }
}
