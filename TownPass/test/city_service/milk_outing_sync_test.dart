import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/service/milk_family_store.dart';
import 'package:town_pass/service/milk_family_sync.dart';
import 'package:town_pass/service/milk_outing.dart';
import 'package:town_pass/service/milk_route.dart';

// Real Dart-to-relay traffic, with separate preference snapshots representing
// phones. The relay's fixed clock keeps Sunday/week-boundary checks repeatable.
class _OutingRealHttp extends HttpOverrides {}

Future<void> _network(Future<void> Function() action) => HttpOverrides.runZoned(
  action,
  createHttpClient: _OutingRealHttp().createHttpClient,
);

final _now = DateTime.utc(2026, 11, 8, 8);
final _plannedAt = DateTime.utc(2026, 11, 8, 9);
const _firstId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _secondId = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _stop = MilkRouteStop(
  name: '全家 測試門市',
  address: '臺北市公開門市地址',
  latitude: 25.03,
  longitude: 121.56,
);

class _OutingRelay {
  _OutingRelay(this.process, this.port);
  final Process process;
  final int port;
  String get url => 'http://127.0.0.1:$port';

  static Future<_OutingRelay> start() async {
    final process = await Process.start('python3', [
      '-u',
      '-c',
      'import server\n'
          'server.time.time = lambda: ${_now.millisecondsSinceEpoch / 1000}\n'
          'relay = server.ThreadingHTTPServer(("127.0.0.1", 0), server.Handler)\n'
          'print(relay.server_address[1], flush=True)\n'
          'relay.serve_forever()\n',
    ], workingDirectory: 'tools/milk_demo_server');
    process.stderr.drain<void>();
    try {
      final line = await process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 10));
      return _OutingRelay(process, int.parse(line));
    } catch (_) {
      process.kill();
      rethrow;
    }
  }

  Future<void> stop() async {
    process.kill();
    await process.exitCode.timeout(const Duration(seconds: 5));
  }
}

MilkChild _child(String id) => MilkChild(
  id: id,
  number: '0123456789012345',
  name: '本機私有學生姓名',
  school: '本機私有學校名稱',
);

Future<Map<String, Object>> _snapshot() async {
  final prefs = await SharedPreferences.getInstance();
  return {for (final key in prefs.getKeys()) key: prefs.get(key)!};
}

MilkOuting _outing(Map<String, dynamic> profile) =>
    MilkOuting.fromProfile(profile, now: _now)!;

Matcher _syncStatus(int status) => isA<MilkSyncException>().having(
  (error) => error.statusCode,
  'HTTP status',
  status,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _OutingRelay relay;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    relay = await _OutingRelay.start();
  });

  tearDown(() async => relay.stop());

  test(
    'child requests, parent plans route stop, both see completion independently of sibling',
    () => _network(() async {
      final first = _child(_firstId), sibling = _child(_secondId);
      final code = await MilkFamilySync.invite(first, relay.url, 0);
      await MilkFamilySync.invite(sibling, relay.url, 1);
      final parent = await _snapshot();

      SharedPreferences.setMockInitialValues({});
      await MilkFamilySync.join(relay.url, code, displayName: '孩子本機私有暱稱');
      final requested = await MilkFamilySync.updateOuting(
        action: 'request',
        expectedRevision: 0,
      );
      expect(_outing(requested).status, 'requested');
      expect(_outing(requested).revision, 1);
      final childPhone = await _snapshot();

      SharedPreferences.setMockInitialValues(parent);
      final observed = (await MilkFamilySync.outingProfile(childId: first.id))!;
      expect(_outing(observed).status, 'requested');
      final planned = await MilkFamilySync.updateOuting(
        childId: first.id,
        action: 'plan',
        expectedRevision: _outing(observed).revision,
        store: _stop.toJson(),
        plannedAt: _plannedAt,
      );
      expect(_outing(planned).status, 'planned');
      expect(_outing(planned).store, _stop.toJson());
      expect(_outing(planned).plannedAt, _plannedAt);
      expect(_outing(planned).whenLabel, '11/8（日）17:00・台北時間');
      final siblingProfile = (await MilkFamilySync.outingProfile(
        childId: sibling.id,
      ))!;
      expect(MilkOuting.fromProfile(siblingProfile, now: _now), isNull);
      // Ordinary parent synchronization retains the local identity while merging
      // the public outing received through the existing profile response.
      final synced = (await MilkFamilySync.syncParent([first, sibling]))!;
      expect(synced.first.name, first.name);
      expect(_outing(synced.first.toJson()).status, 'planned');
      expect(synced.last.outing, isNull);

      SharedPreferences.setMockInitialValues(childPhone);
      final seenByChild = (await MilkFamilySync.outingProfile())!;
      expect(_outing(seenByChild).store, _stop.toJson());
      expect(_outing(seenByChild).plannedAt, _plannedAt);
      final completed = await MilkFamilySync.childRecord({
        'week': milkOutingWeek(_now),
        'product': '豆漿',
        'date': '2026/11/08 17:10',
      });
      expect(_outing(completed).status, 'completed');
      expect(_outing(completed).revision, 3);
      final cached = jsonDecode(
        (await SharedPreferences.getInstance()).getString('milk_child_cache')!,
      ) as Map<String, dynamic>;
      expect(_outing(cached).status, 'completed');

      SharedPreferences.setMockInitialValues(parent);
      final parentSees = (await MilkFamilySync.outingProfile(
        childId: first.id,
      ))!;
      expect(_outing(parentSees).status, 'completed');
      expect((parentSees['records'] as List).single['product'], '豆漿');
      final siblingStill = (await MilkFamilySync.outingProfile(
        childId: sibling.id,
      ))!;
      expect(siblingStill['records'], isEmpty);
      expect(siblingStill['outing'], isNull);
    }),
  );

  test(
    'client preserves public-only store boundary and keeps route endpoints local',
    () => _network(() async {
      final first = _child(_firstId);
      final code = await MilkFamilySync.invite(first, relay.url, 0);
      const privateRoute = MilkRoute(
        school: LatLng(25.021111, 121.521111),
        home: LatLng(25.041111, 121.541111),
      );
      await MilkRouteStore.save(privateRoute);
      final before = await _snapshot();
      // Extra local metadata is deliberately supplied here: the client must build
      // the allowlisted store object instead of forwarding the entire map.
      await MilkFamilySync.updateOuting(
        childId: first.id,
        action: 'plan',
        expectedRevision: 0,
        plannedAt: _plannedAt,
        store: {
          ..._stop.toJson(),
          'home': privateRoute.home.latitude,
          'school': first.school,
          'cardNumber': first.number,
          'localName': first.name,
        },
      );
      final shared = (await MilkFamilySync.outingProfile(childId: first.id))!;
      final serialized = jsonEncode(shared);
      for (final private in [
        first.number,
        first.name,
        first.school,
        '25.021111',
        '121.521111',
        '25.041111',
        '121.541111',
        'localName',
        'cardNumber',
        'home',
        'school',
      ]) {
        expect(serialized, isNot(contains(private)));
      }
      expect(_outing(shared).store, _stop.toJson());
      expect(
        (await _snapshot())[MilkRouteStore.key],
        before[MilkRouteStore.key],
      );
      expect((await MilkRouteStore.load())!.toJson(), privateRoute.toJson());

      SharedPreferences.setMockInitialValues({});
      await MilkFamilySync.join(relay.url, code);
      final childView = (await MilkFamilySync.outingProfile())!;
      expect(_outing(childView).store, _stop.toJson());
      expect(await MilkRouteStore.load(), isNull);
    }),
  );

  test(
    'stale phone receives conflict, reloads latest plan, revoked child cannot mutate',
    () => _network(() async {
      final first = _child(_firstId);
      final code = await MilkFamilySync.invite(first, relay.url, 0);
      final parent = await _snapshot();
      SharedPreferences.setMockInitialValues({});
      await MilkFamilySync.join(relay.url, code);
      await MilkFamilySync.updateOuting(action: 'request', expectedRevision: 0);
      final childPhone = await _snapshot();

      SharedPreferences.setMockInitialValues(parent);
      await MilkFamilySync.updateOuting(
        childId: first.id,
        action: 'plan',
        expectedRevision: 1,
        store: _stop.toJson(),
        plannedAt: _plannedAt,
      );
      SharedPreferences.setMockInitialValues(childPhone);
      await expectLater(
        MilkFamilySync.updateOuting(action: 'cancel', expectedRevision: 1),
        throwsA(_syncStatus(409)),
      );
      final refreshed = (await MilkFamilySync.outingProfile())!;
      expect(_outing(refreshed).status, 'planned');
      expect(_outing(refreshed).revision, 2);
      final updatedChildPhone = await _snapshot();

      SharedPreferences.setMockInitialValues(parent);
      await MilkFamilySync.revoke(first.id);
      expect(await MilkFamilySync.outingProfile(childId: first.id), isNull);
      SharedPreferences.setMockInitialValues(updatedChildPhone);
      await expectLater(
        MilkFamilySync.updateOuting(action: 'cancel', expectedRevision: 2),
        throwsA(_syncStatus(401)),
      );
      await expectLater(
        MilkFamilySync.outingProfile(),
        throwsA(_syncStatus(401)),
      );
    }),
  );

  test('model expires Taipei Sunday plan exactly at Monday, independent of device zone', () {
    final sunday = DateTime.parse('2026-11-08T15:59:59Z');
    final monday = DateTime.parse('2026-11-08T16:00:00Z');
    final profile = {
      'outing': {
        'week': '2026-11-02',
        'status': 'planned',
        'revision': 2,
        'store': _stop.toJson(),
        'plannedAt': '2026-11-08T09:00:00+00:00',
      },
    };
    expect(milkOutingWeek(sunday), '2026-11-02');
    expect(milkOutingWeek(monday), '2026-11-09');
    expect(
      MilkOuting.fromProfile(profile, now: sunday)!.whenLabel,
      '11/8（日）17:00・台北時間',
    );
    expect(MilkOuting.fromProfile(profile, now: monday), isNull);
    expect(
      milkOutingWeek(DateTime.parse('2026-11-09T01:00:00+09:00')),
      '2026-11-09',
    );
  });
}
