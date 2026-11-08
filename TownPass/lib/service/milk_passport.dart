/// A read-only view of existing pickup records for the local 3D passport.
///
/// The renderer receives only stamp metadata. Opening, replaying, or rendering
/// this projection never records a pickup or creates a second progress store.
class MilkPassport {
  MilkPassport._(Iterable<Map<String, String>> values)
    : stamps = List<Map<String, String>>.unmodifiable(
        values.map((stamp) => Map<String, String>.unmodifiable(stamp)),
      );

  factory MilkPassport.fromRecords(Iterable<Map<String, dynamic>> records) {
    final byWeek = <String, Map<String, String>>{};
    // Existing app histories are newest-first. Preserve the first valid
    // record for a week when the same week appears more than once.
    for (final record in records) {
      final week = _week(record['week']);
      final type = switch (record['product']) {
        '鮮奶' => 'milk',
        '豆漿' => 'soy',
        _ => null,
      };
      if (week == null || type == null || byWeek.containsKey(week)) {
        continue;
      }
      // confirmedAt belongs to the relay's simulated-transaction record, not
      // the ordinary local record schema. Invalid/missing server timestamps
      // may still use the existing display date if that date is valid.
      final confirmed = record['source'] == 'demo_transaction'
          ? _instantDate(record['confirmedAt'])
          : null;
      final date = confirmed ?? _recordDate(record['date']);
      if (date == null) continue;
      final daysFromMonday = DateTime.parse(date)
          .difference(DateTime.parse(week))
          .inDays;
      // A legacy/inconsistent record remains untouched in the app history,
      // but cannot be sent as an invalid stamp that rejects the whole book.
      if (daysFromMonday < 0 || daysFromMonday >= 7) continue;
      byWeek[week] = {
        'id': 'pickup-$week',
        'type': type,
        'week': week,
        'date': date,
      };
    }
    final weeks = byWeek.keys.toList()..sort();
    return MilkPassport._(weeks.map((week) => byWeek[week]!));
  }

  final List<Map<String, String>> stamps;
  int get count => stamps.length;

  Map<String, dynamic> payload({
    bool replayLatest = false,
    bool reduceMotion = false,
  }) => {
    'version': 1,
    'stamps': [for (final stamp in stamps) Map<String, String>.from(stamp)],
    'replayLatest': replayLatest,
    'reduceMotion': reduceMotion,
  };

  static DateTime? _calendar(int year, int month, int day) {
    if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1) {
      return null;
    }
    final value = DateTime.utc(year, month, day);
    return value.year == year && value.month == month && value.day == day
        ? value
        : null;
  }

  static String? _week(dynamic input) {
    if (input is! String) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(input);
    if (match == null) return null;
    final date = _calendar(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
    return date?.weekday == DateTime.monday ? input : null;
  }

  static String _dateLabel(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String? _recordDate(dynamic input) {
    if (input is! String) return null;
    // Display dates written by the app are Taipei calendar values. Do not let
    // the device's current time zone reinterpret them as a different day.
    final match = RegExp(
      r'^(\d{4})([-/])(\d{2})\2(\d{2})(?: (\d{2}):(\d{2})(?::(\d{2}))?)?$',
    ).firstMatch(input);
    if (match == null) return _instantDate(input);
    final date = _calendar(
      int.parse(match[1]!),
      int.parse(match[3]!),
      int.parse(match[4]!),
    );
    if (date == null ||
        (match[5] != null && int.parse(match[5]!) > 23) ||
        (match[6] != null && int.parse(match[6]!) > 59) ||
        (match[7] != null && int.parse(match[7]!) > 59)) {
      return null;
    }
    // The passport displays the recorded calendar date, not an invented time.
    return _dateLabel(date);
  }

  static String? _instantDate(dynamic input) {
    if (input is! String) return null;
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})[Tt](\d{2}):(\d{2})'
      r'(?::(\d{2})(?:\.(\d{1,6}))?)?([Zz]|[+-]\d{2}:\d{2})$',
    ).firstMatch(input);
    if (match == null ||
        _calendar(
              int.parse(match[1]!),
              int.parse(match[2]!),
              int.parse(match[3]!),
            ) ==
            null ||
        int.parse(match[4]!) > 23 ||
        int.parse(match[5]!) > 59 ||
        (match[6] != null && int.parse(match[6]!) > 59)) {
      return null;
    }
    final offset = match[8]!;
    if (offset.length > 1 &&
        (int.parse(offset.substring(1, 3)) > 23 ||
            int.parse(offset.substring(4, 6)) > 59)) {
      return null;
    }
    final parsed = DateTime.tryParse(input.toUpperCase());
    if (parsed == null) return null;
    final taipeiDate = parsed.toUtc().add(const Duration(hours: 8));
    if (taipeiDate.year < 1 || taipeiDate.year > 9999) return null;
    return _dateLabel(taipeiDate);
  }
}
