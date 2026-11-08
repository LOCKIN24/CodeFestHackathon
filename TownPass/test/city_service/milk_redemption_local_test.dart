import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/service/milk_redemption_demo.dart';

const _sentinels = <String, Object>{
  'milk_family_v2': 'original-family-private-sentinel',
  'milk_sync_parent_token': 'original-parent-sentinel',
  'milk_sync_child_token': 'original-child-sentinel',
  'milk_child_cache': 'original-child-cache',
  'milk_selected_child_v2': 'original-selected-child',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(_sentinels));

  test(
    'local service creates an empty isolated family without network',
    () async {
      var networkCalls = 0;
      await HttpOverrides.runZoned(
        () async {
          final session = await MilkRedemptionDemo.open('local');
          expect(session.url, 'local');
          expect(session.children.length, 2);
          expect(session.children.map((c) => c['id']).toSet().length, 2);
          expect(
            session.children.every((c) => (c['records'] as List).isEmpty),
            isTrue,
          );
          expect(await MilkRedemptionDemo.savedUrl(), 'local');
        },
        createHttpClient: (_) {
          networkCalls++;
          throw StateError('Unexpected network');
        },
      );
      expect(networkCalls, 0);
    },
  );

  test('local pickup persists server-shaped timestamps and keeps siblings independent', () async {
    final session = await MilkRedemptionDemo.open('local');
    final result = await MilkRedemptionDemo.redeem(
      session,
      'DEMO-CARD-02',
      '豆漿',
    );
    expect(result.result, 'accepted');
    final record = (result.child['records'] as List).single as Map;
    expect(record['source'], 'demo_transaction');
    expect(record['product'], '豆漿');
    expect(record['transactionId'], matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(record['confirmedAt'], endsWith('+08:00'));
    expect(
      DateTime.now()
          .toUtc()
          .difference(DateTime.parse(record['confirmedAt'] as String))
          .abs(),
      lessThan(const Duration(seconds: 10)),
    );
    final resumed = await MilkRedemptionDemo.open('local');
    expect(resumed.token, session.token);
    expect(resumed.children.first['records'], isEmpty);
    expect(resumed.children.last['records'], [record]);
    final event = await MilkRedemptionDemo.lastEvent(resumed, 'DEMO-CARD-02');
    expect(event!['transactionId'], record['transactionId']);
    final prefs = await SharedPreferences.getInstance();
    for (final entry in _sentinels.entries) {
      expect(prefs.get(entry.key), entry.value);
    }
  });

  test(
    'repeated and racing pickups retain one original transaction and product',
    () async {
      final session = await MilkRedemptionDemo.open('local');
      final responses = await Future.wait([
        MilkRedemptionDemo.redeem(session, 'DEMO-CARD-01', '鮮奶'),
        MilkRedemptionDemo.redeem(session, 'DEMO-CARD-01', '豆漿'),
      ]);
      expect(responses.map((r) => r.result), [
        'accepted',
        'duplicate_transaction',
      ]);
      final replay = await MilkRedemptionDemo.redeem(
        session,
        'DEMO-CARD-01',
        '豆漿',
        repeat: true,
      );
      expect(replay.result, 'duplicate_transaction');
      final records = replay.child['records'] as List;
      expect(records.length, 1);
      expect((records.single as Map)['product'], '鮮奶');
      expect(
        (responses.first.child['records'] as List).single['transactionId'],
        (records.single as Map)['transactionId'],
      );
    },
  );

  test(
    'new week preserves old history and creates exactly one new pickup',
    () async {
      final session = await MilkRedemptionDemo.open('local');
      await MilkRedemptionDemo.redeem(session, 'DEMO-CARD-01', '豆漿');
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(
        prefs.getString(MilkRedemptionDemo.preferenceKey)!,
      ) as Map<String, dynamic>;
      final event = (saved['events'] as Map)['DEMO-CARD-01'] as Map;
      final record =
          ((saved['children'] as List).first['records'] as List).single as Map;
      event['week'] = record['week'] = '2000-01-03';
      record['date'] = '2000/01/04 10:00';
      record['confirmedAt'] = '2000-01-04T10:00:00+08:00';
      await prefs.setString(
        MilkRedemptionDemo.preferenceKey,
        jsonEncode(saved),
      );
      final result = await MilkRedemptionDemo.redeem(
        session,
        'DEMO-CARD-01',
        '鮮奶',
      );
      expect(result.result, 'accepted');
      final records = result.child['records'] as List;
      expect(records.length, 2);
      expect(records.first['product'], '鮮奶');
      expect(records.last['week'], '2000-01-03');
      expect(
        records.first['transactionId'],
        isNot(records.last['transactionId']),
      );
    },
  );

  test(
    'rebuild invalidates old session and leaves ordinary data untouched',
    () async {
      final old = await MilkRedemptionDemo.open('local');
      await MilkRedemptionDemo.redeem(old, 'DEMO-CARD-01', '鮮奶');
      final replacement = await MilkRedemptionDemo.open('local', fresh: true);
      expect(replacement.token, isNot(old.token));
      expect(
        replacement.children.every((c) => (c['records'] as List).isEmpty),
        isTrue,
      );
      await expectLater(
        MilkRedemptionDemo.redeem(old, 'DEMO-CARD-01', '豆漿'),
        throwsStateError,
      );
      await expectLater(MilkRedemptionDemo.refresh(old), throwsStateError);
      expect(await MilkRedemptionDemo.lastEvent(old, 'DEMO-CARD-01'), isNull);
      final prefs = await SharedPreferences.getInstance();
      for (final entry in _sentinels.entries) {
        expect(prefs.get(entry.key), entry.value);
      }
    },
  );

  test(
    'invalid requests and transport switches cannot create local success',
    () async {
      final session = await MilkRedemptionDemo.open('local');
      await expectLater(
        MilkRedemptionDemo.redeem(session, 'DEMO-CARD-01', '咖啡'),
        throwsFormatException,
      );
      await expectLater(
        MilkRedemptionDemo.redeem(session, 'UNKNOWN', '鮮奶'),
        throwsFormatException,
      );
      await expectLater(
        MilkRedemptionDemo.redeem(session, 'DEMO-CARD-01', '鮮奶', repeat: true),
        throwsStateError,
      );
      await expectLater(
        MilkRedemptionDemo.open('http://127.0.0.1:8766'),
        throwsFormatException,
      );
      expect(
        (await MilkRedemptionDemo.refresh(session)).children
            .every((c) => (c['records'] as List).isEmpty),
        isTrue,
      );
    },
  );
}
