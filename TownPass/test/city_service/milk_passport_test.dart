import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:town_pass/service/milk_passport.dart';

Map<String, dynamic> _record(String week, String product, String date) => {
  'week': week,
  'product': product,
  'date': date,
};

void main() {
  test('empty records never import the standalone demo sample stamps', () {
    final passport = MilkPassport.fromRecords([]);
    expect(passport.count, 0);
    expect(passport.stamps, isEmpty);
    expect(passport.payload()['stamps'], isEmpty);
  });

  test('milk and soy records have equal progress and retain missed weeks', () {
    final passport = MilkPassport.fromRecords([
      _record('2026-11-02', '豆漿', '2026/11/08 06:04'),
      _record('2026-10-19', '鮮奶', '2026/10/20'),
      _record('2026-09-28', '豆漿', '2026/10/01 18:00'),
    ]);
    expect(passport.count, 3);
    expect(passport.stamps.map((s) => s['week']), [
      '2026-09-28',
      '2026-10-19',
      '2026-11-02',
    ]);
    expect(passport.stamps.map((s) => s['type']), ['soy', 'milk', 'soy']);
    expect(passport.stamps.last['date'], '2026-11-08');
  });

  test('first valid record in a week remains authoritative', () {
    final passport = MilkPassport.fromRecords([
      _record('2026-11-02', '不明飲品', '2026/11/08'),
      _record('2026-11-02', '鮮奶', 'not a date'),
      _record('2026-11-02', '豆漿', '2026/11/08'),
      _record('2026-11-02', '鮮奶', '2026/11/07'),
    ]);
    expect(passport.count, 1);
    expect(passport.stamps.single, {
      'id': 'pickup-2026-11-02',
      'type': 'soy',
      'week': '2026-11-02',
      'date': '2026-11-08',
    });
  });

  test('invalid weeks, calendar dates and times cannot create stamps', () {
    final passport = MilkPassport.fromRecords([
      _record('2026-11-03', '鮮奶', '2026/11/08'),
      _record('2026-02-30', '鮮奶', '2026/02/28'),
      _record('0000-01-03', '鮮奶', '0000/01/03'),
      _record('2026-11-02 ', '鮮奶', '2026/11/08'),
      _record('2026-11-02', '鮮奶', '2026/02/30'),
      _record('2026-11-02', '鮮奶', '2026/11/08 24:00'),
      _record('2026-11-02', '鮮奶', '2026/11/08 12:60'),
      _record('2026-11-02', '鮮奶', '2026-02-30T00:00:00Z'),
      _record('2026-11-02', '鮮奶', '2026-11-08T24:00:00Z'),
      _record('2026-11-02', '鮮奶', '2026-11-08T12:00:00+24:00'),
      _record('2026-11-02', '鮮奶', '2026-11-08T12:00:00+08:60'),
      _record('2026-11-02', '鮮奶', '2026-11-08T12:00:00'),
    ]);
    expect(passport.stamps, isEmpty);
  });

  test('date-only and Taipei display dates retain their calendar day', () {
    for (final date in [
      '2026/11/08',
      '2026-11-08',
      '2026/11/08 00:01',
      '2026-11-08 23:59:59',
    ]) {
      final passport = MilkPassport.fromRecords([
        _record('2026-11-02', '鮮奶', date),
      ]);
      expect(passport.stamps.single['date'], '2026-11-08');
    }
    final leapDay = MilkPassport.fromRecords([
      _record('2024-02-26', '鮮奶', '2024/02/29'),
    ]);
    expect(leapDay.stamps.single['date'], '2024-02-29');
  });

  test(
    'server confirmation and explicit ISO instants display Taipei dates',
    () {
      final passport = MilkPassport.fromRecords([
        {
          ..._record('2026-11-02', '豆漿', '2026/11/07 23:59'),
          'source': 'demo_transaction',
          'confirmedAt': '2026-11-07T16:01:00Z',
        },
        _record('2026-10-26', '鮮奶', '2026-10-31T16:01:00.123456Z'),
        _record('2026-10-19', '豆漿', '2026-10-20T00:01:00+09:00'),
      ]);
      expect(passport.stamps.map((s) => s['date']), [
        '2026-10-19',
        '2026-11-01',
        '2026-11-08',
      ]);
    },
  );

  test('ordinary records ignore unrelated confirmation fields', () {
    final passport = MilkPassport.fromRecords([
      {
        ..._record('2026-11-02', '鮮奶', '2026/11/08'),
        'confirmedAt': '2026-11-07T00:00:00Z',
      },
    ]);
    expect(passport.stamps.single['date'], '2026-11-08');
  });

  test('inconsistent week/date records cannot reject the complete book', () {
    final records = [
      _record('2026-11-02', '鮮奶', '2026/11/09'),
      _record('2026-11-02', '豆漿', '2026/11/01'),
      {
        ..._record('2026-11-02', '鮮奶', '2026/11/08'),
        'source': 'demo_transaction',
        // Server instant is already Monday in Taipei, outside this week.
        'confirmedAt': '2026-11-08T16:01:00Z',
      },
      _record('2026-11-02', '豆漿', '2026/11/02'),
      _record('2026-11-09', '鮮奶', '2026/11/15'),
    ];
    final before = jsonEncode(records);
    final passport = MilkPassport.fromRecords(records);
    expect(passport.stamps.map((s) => s['date']), ['2026-11-02', '2026-11-15']);
    expect(passport.stamps.map((s) => s['type']), ['soy', 'milk']);
    expect(jsonEncode(records), before);
  });

  test('malformed confirmation can use the existing valid display date', () {
    final passport = MilkPassport.fromRecords([
      {
        ..._record('2026-11-02', '豆漿', '2026/11/08'),
        'source': 'demo_transaction',
        'confirmedAt': 'broken',
      },
    ]);
    expect(passport.stamps.single['date'], '2026-11-08');
  });

  test('only public stamp metadata leaves the projection', () {
    final record = {
      ..._record('2026-11-02', '豆漿', '2026/11/08'),
      'name': '私有姓名',
      'school': '私有學校',
      'number': '1234567890123456',
      'store': '私有門市',
      'transactionId': 'private-transaction',
      'token': 'private-token',
      'childId': 'private-child-id',
    };
    final stamp = MilkPassport.fromRecords([record]).stamps.single;
    expect(stamp.keys, unorderedEquals(['id', 'type', 'week', 'date']));
    final encoded = jsonEncode(stamp);
    for (final value in [
      '私有姓名',
      '私有學校',
      '1234567890123456',
      '私有門市',
      'private-transaction',
      'private-token',
      'private-child-id',
    ]) {
      expect(encoded, isNot(contains(value)));
    }
  });

  test('siblings and replay payloads cannot mix or change progress', () {
    final records = [_record('2026-11-02', '豆漿', '2026/11/08')];
    final before = jsonEncode(records);
    final first = MilkPassport.fromRecords(records);
    final sibling = MilkPassport.fromRecords([]);
    final payload = first.payload(replayLatest: true, reduceMotion: true);
    expect(payload, {
      'version': 1,
      'stamps': first.stamps,
      'replayLatest': true,
      'reduceMotion': true,
    });
    (payload['stamps'] as List).clear();
    records.single['product'] = '鮮奶';
    expect(first.stamps.single['type'], 'soy');
    expect(first.count, 1);
    expect(sibling.count, 0);
    expect(before, contains('豆漿'));
    expect(first.payload()['replayLatest'], isFalse);
    expect(() => first.stamps.clear(), throwsUnsupportedError);
    expect(() => first.stamps.single['type'] = 'milk', throwsUnsupportedError);
  });
}
