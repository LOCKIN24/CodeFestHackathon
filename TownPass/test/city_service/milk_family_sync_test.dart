import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/service/milk_family_store.dart';
import 'package:town_pass/service/milk_family_sync.dart';
import 'package:town_pass/service/milk_invitation_qr.dart';

// Exercise the Dart client against the same Python relay used at the event.
// Separate preference snapshots represent separate phones; no real user data
// or physical device is used by these tests.
class _RealHttp extends HttpOverrides {}

Future<void> _network(Future<void> Function() action) => HttpOverrides.runZoned(
  action,
  createHttpClient: _RealHttp().createHttpClient,
);

class _Relay {
  _Relay(this.process, this.port);
  final Process process;
  final int port;
  String get url => 'http://127.0.0.1:$port';

  static Future<_Relay> start() async {
    final process = await Process.start('python3', [
      '-u',
      '-c',
      'import server\n'
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
      return _Relay(process, int.parse(line));
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

MilkChild _child(String id, {List<Map<String, dynamic>> records = const []}) =>
    MilkChild(
      id: id,
      number: '0123456789012345',
      name: '測試學生私有姓名',
      school: '測試學校私有資料',
      records: records,
    );

Map<String, dynamic> _record(String week, {String product = '鮮奶'}) => {
  'week': week,
  'product': product,
  'date': '${week.replaceAll('-', '/')} 09:00',
};

Future<Map<String, Object>> _snapshot() async {
  final prefs = await SharedPreferences.getInstance();
  return {for (final key in prefs.getKeys()) key: prefs.get(key)!};
}

Future<Map<String, dynamic>> _parentPayload(String url, String token) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('$url/v1/parent/children'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final response = await request.close();
    expect(response.statusCode, 200);
    return jsonDecode(await response.transform(utf8.decoder).join())
        as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

Future<String> _closedUrl() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return 'http://127.0.0.1:$port';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Relay relay;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    relay = await _Relay.start();
  });

  tearDown(() async => relay.stop());

  test(
    'private student and store data stay on the parent phone',
    () => _network(() async {
      final local = _child(
        'a' * 32,
        records: [
          {..._record('2026-11-02'), 'store': '家附近私有門市'},
        ],
      );
      await MilkFamilySync.invite(local, relay.url, 0);
      final prefs = await SharedPreferences.getInstance();
      final payload = await _parentPayload(
        relay.url,
        prefs.getString('milk_sync_parent_token')!,
      );
      final shared = (payload['children'] as List).single as Map;
      expect(shared.keys, unorderedEquals(['id', 'alias', 'records']));
      expect(shared['alias'], '孩子1');
      expect((shared['records'] as List).single, _record('2026-11-02'));
      final serialized = jsonEncode(payload);
      for (final value in [local.number, local.name, local.school, '家附近私有門市']) {
        expect(serialized, isNot(contains(value)));
      }
      final merged = (await MilkFamilySync.syncParent([local]))!.single;
      expect(merged.records.single['store'], '家附近私有門市');
      expect(merged.number, local.number);
      expect(merged.name, local.name);
      expect(merged.school, local.school);
    }),
  );

  test(
    'two phones sync in both directions without mixing children',
    () => _network(() async {
      final first = _child('a' * 32);
      final second = _child('b' * 32);
      final codeA = await MilkFamilySync.invite(first, relay.url, 0);
      final codeB = await MilkFamilySync.invite(second, relay.url, 1);
      final parent = await _snapshot();

      SharedPreferences.setMockInitialValues({});
      await MilkFamilySync.join(relay.url, codeA, displayName: '本機暱稱');
      await MilkFamilySync.childRecord(_record('2026-11-02'));
      final phoneA = await _snapshot();

      SharedPreferences.setMockInitialValues({});
      await MilkFamilySync.join(relay.url, codeB);
      final profileB = await MilkFamilySync.childProfile();
      expect(profileB['id'], second.id);
      expect(profileB['records'], isEmpty);
      final phoneB = await _snapshot();

      SharedPreferences.setMockInitialValues(parent);
      final synced = (await MilkFamilySync.syncParent([first, second]))!;
      expect(synced.first.records, [_record('2026-11-02')]);
      expect(synced.last.records, isEmpty);
      final newer = _record('2026-11-09', product: '豆漿');
      await MilkFamilySync.syncParent([
        _child(first.id, records: [newer, ...synced.first.records]),
        synced.last,
      ]);

      SharedPreferences.setMockInitialValues(phoneA);
      final profileA = await MilkFamilySync.childProfile();
      expect(profileA['id'], first.id);
      expect(profileA['records'], [newer, _record('2026-11-02')]);
      SharedPreferences.setMockInitialValues(phoneB);
      expect((await MilkFamilySync.childProfile())['records'], isEmpty);
    }),
  );

  test(
    'relay resolves same-week conflicts without deleting local metadata',
    () => _network(() async {
      final first = _child('a' * 32);
      final code = await MilkFamilySync.invite(first, relay.url, 0);
      final parent = await _snapshot();
      SharedPreferences.setMockInitialValues({});
      await MilkFamilySync.join(relay.url, code);
      await MilkFamilySync.childRecord(_record('2026-11-02', product: '豆漿'));
      SharedPreferences.setMockInitialValues(parent);
      final result = (await MilkFamilySync.syncParent([
        _child(
          first.id,
          records: [
            {..._record('2026-11-02'), 'store': '僅本機門市'},
          ],
        ),
      ]))!.single;
      expect(result.records, [
        {..._record('2026-11-02', product: '豆漿'), 'store': '僅本機門市'},
      ]);
    }),
  );

  test(
    'offline requests preserve data and recover on the same relay',
    () => _network(() async {
      final first = _child('a' * 32);
      final code = await MilkFamilySync.invite(first, relay.url, 0);
      final parent = await _snapshot();
      SharedPreferences.setMockInitialValues({});
      await MilkFamilySync.join(relay.url, code);
      await MilkFamilySync.childProfile();
      final child = await _snapshot();
      final unavailable = await _closedUrl();
      var prefs = await SharedPreferences.getInstance();
      await prefs.setString('milk_sync_child_url', unavailable);
      await expectLater(
        MilkFamilySync.childProfile(),
        throwsA(isA<SocketException>()),
      );
      expect(prefs.getString('milk_child_cache'), child['milk_child_cache']);
      expect(await MilkFamilySync.isChild, isTrue);
      await prefs.setString('milk_sync_child_url', relay.url);
      expect((await MilkFamilySync.childProfile())['id'], first.id);

      SharedPreferences.setMockInitialValues(parent);
      prefs = await SharedPreferences.getInstance();
      await prefs.setString('milk_sync_parent_url', unavailable);
      final localRecord = _child(first.id, records: [_record('2026-11-02')]);
      await expectLater(
        MilkFamilySync.syncParent([localRecord]),
        throwsA(isA<SocketException>()),
      );
      expect(await MilkFamilySync.isShared(first.id), isTrue);
      expect(localRecord.records, [_record('2026-11-02')]);
      await prefs.setString('milk_sync_parent_url', relay.url);
      expect((await MilkFamilySync.syncParent([localRecord]))!.single.records, [
        _record('2026-11-02'),
      ]);
      await prefs.setString('milk_sync_parent_url', unavailable);
      expect(await MilkFamilySync.clearParent(), isFalse);
      expect(await MilkFamilySync.parentUrl, isNull);
    }),
  );

  test(
    'new join replaces the previous child cache and invitation is single use',
    () => _network(() async {
      final first = _child('a' * 32, records: [_record('2026-11-02')]);
      final second = _child('b' * 32);
      final codeA = await MilkFamilySync.invite(first, relay.url, 0);
      final codeB = await MilkFamilySync.invite(second, relay.url, 1);
      SharedPreferences.setMockInitialValues({});
      await MilkFamilySync.join(relay.url, codeA, displayName: '前一個孩子');
      var prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('milk_child_cache')!)['id'], first.id);
      await MilkFamilySync.join(relay.url, codeB, displayName: '  新孩子  ');
      prefs = await SharedPreferences.getInstance();
      final cache = jsonDecode(prefs.getString('milk_child_cache')!) as Map;
      expect(cache['id'], second.id);
      expect(cache['records'], isEmpty);
      expect(prefs.getString('milk_child_local_name'), '新孩子');
      await expectLater(
        MilkFamilySync.join(relay.url, codeB),
        throwsA(
          isA<MilkSyncException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.sessionExpired, 'sessionExpired', isFalse),
        ),
      );
      expect(jsonDecode(prefs.getString('milk_child_cache')!)['id'], second.id);
    }),
  );

  test(
    'revoke invalidates only the selected child and returns typed 401',
    () => _network(() async {
      final first = _child('a' * 32);
      final second = _child('b' * 32);
      final codeA = await MilkFamilySync.invite(first, relay.url, 0);
      final codeB = await MilkFamilySync.invite(second, relay.url, 1);
      final parent = await _snapshot();
      SharedPreferences.setMockInitialValues({});
      await MilkFamilySync.join(relay.url, codeA);
      final phoneA = await _snapshot();
      SharedPreferences.setMockInitialValues({});
      await MilkFamilySync.join(relay.url, codeB);
      final phoneB = await _snapshot();
      SharedPreferences.setMockInitialValues(parent);
      await MilkFamilySync.revoke(first.id);
      expect(await MilkFamilySync.isShared(first.id), isFalse);
      expect(await MilkFamilySync.isShared(second.id), isTrue);
      SharedPreferences.setMockInitialValues(phoneA);
      final expired = isA<MilkSyncException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.sessionExpired, 'sessionExpired', isTrue);
      await expectLater(MilkFamilySync.childProfile(), throwsA(expired));
      await expectLater(
        MilkFamilySync.childRecord(_record('2026-11-02')),
        throwsA(expired),
      );
      SharedPreferences.setMockInitialValues(phoneB);
      expect((await MilkFamilySync.childProfile())['id'], second.id);
    }),
  );

  test(
    'reset revokes old links while retaining local family data',
    () => _network(() async {
      final first = _child('a' * 32, records: [_record('2026-11-02')]);
      final second = _child('b' * 32);
      await MilkFamilyStore.save([first, second]);
      final codeA = await MilkFamilySync.invite(first, relay.url, 0);
      final codeB = await MilkFamilySync.invite(second, relay.url, 1);
      final parent = await _snapshot();
      SharedPreferences.setMockInitialValues({});
      await MilkFamilySync.join(relay.url, codeA);
      final child = await _snapshot();
      SharedPreferences.setMockInitialValues(parent);
      expect(await MilkFamilySync.clearParent(), isTrue);
      expect(await MilkFamilySync.parentUrl, isNull);
      expect(await MilkFamilySync.isShared(first.id), isFalse);
      expect((await MilkFamilyStore.load()).length, 2);
      expect((await MilkFamilyStore.load()).first.records, first.records);
      final resetParent = await _snapshot();
      SharedPreferences.setMockInitialValues(child);
      await expectLater(
        MilkFamilySync.childProfile(),
        throwsA(
          isA<MilkSyncException>().having(
            (e) => e.sessionExpired,
            'sessionExpired',
            isTrue,
          ),
        ),
      );
      await expectLater(
        MilkFamilySync.join(relay.url, codeB),
        throwsA(
          isA<MilkSyncException>().having(
            (e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
      await MilkFamilySync.leaveChild();
      expect(await MilkFamilySync.isChild, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('milk_child_cache'), isNull);
      expect(prefs.getString('milk_child_local_name'), isNull);
      SharedPreferences.setMockInitialValues(resetParent);
      expect(await MilkFamilySync.invite(first, relay.url, 0), isNotEmpty);
    }),
  );

  test(
    'missing and restarted sessions return typed expiry errors',
    () => _network(() async {
      await expectLater(
        MilkFamilySync.childProfile(),
        throwsA(
          isA<MilkSyncException>().having(
            (e) => e.sessionExpired,
            'sessionExpired',
            isTrue,
          ),
        ),
      );
      final first = _child('a' * 32);
      final code = await MilkFamilySync.invite(first, relay.url, 0);
      final parent = await _snapshot();
      SharedPreferences.setMockInitialValues({});
      await MilkFamilySync.join(relay.url, code);
      final child = await _snapshot();
      final replacement = await _Relay.start();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('milk_sync_child_url', replacement.url);
        await expectLater(
          MilkFamilySync.childProfile(),
          throwsA(
            isA<MilkSyncException>().having(
              (e) => e.sessionExpired,
              'sessionExpired',
              isTrue,
            ),
          ),
        );
        expect(prefs.getString('milk_child_cache'), child['milk_child_cache']);
        SharedPreferences.setMockInitialValues(parent);
        final parentPrefs = await SharedPreferences.getInstance();
        await parentPrefs.setString('milk_sync_parent_url', replacement.url);
        await expectLater(
          MilkFamilySync.syncParent([first]),
          throwsA(
            isA<MilkSyncException>().having(
              (e) => e.sessionExpired,
              'sessionExpired',
              isTrue,
            ),
          ),
        );
        // A 401 proves the replacement relay has no old family to revoke.
        expect(await MilkFamilySync.clearParent(), isTrue);
        expect(await MilkFamilySync.parentUrl, isNull);
        expect(await MilkFamilySync.isShared(first.id), isFalse);
      } finally {
        await replacement.stop();
      }
    }),
  );

  test(
    'late child responses cannot refill a left or replaced link cache',
    () => _network(() async {
      for (final recordRequest in [false, true]) {
        for (final rejoin in [false, true]) {
          final delayed = await HttpServer.bind(
            InternetAddress.loopbackIPv4,
            0,
          );
          final arrived = Completer<HttpRequest>();
          final subscription = delayed.listen(arrived.complete);
          try {
            final url = 'http://127.0.0.1:${delayed.port}';
            SharedPreferences.setMockInitialValues({
              'milk_sync_child_url': url,
              'milk_sync_child_token': 'old-device-token',
              'milk_child_cache': jsonEncode({'id': 'old-child'}),
            });
            final pending = recordRequest
                ? MilkFamilySync.childRecord(_record('2026-11-02'))
                : MilkFamilySync.childProfile();
            final request = await arrived.future.timeout(
              const Duration(seconds: 3),
            );
            // The request has read its old credentials, but its response is
            // held until after the user leaves or changes the linked child.
            await request.drain<void>();
            await MilkFamilySync.leaveChild();
            final prefs = await SharedPreferences.getInstance();
            final replacementCache = jsonEncode({'id': 'new-child'});
            if (rejoin) {
              await prefs.setString('milk_sync_child_url', url);
              await prefs.setString(
                'milk_sync_child_token',
                'new-device-token',
              );
              await prefs.setString('milk_child_cache', replacementCache);
            }
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'child': {'id': 'old-child', 'alias': '孩子1', 'records': []},
              }),
            );
            await request.response.close();
            await pending;
            expect(
              prefs.getString('milk_child_cache'),
              rejoin ? replacementCache : isNull,
            );
          } finally {
            await subscription.cancel();
            await delayed.close(force: true);
          }
        }
      }
    }),
  );
  test(
    'QR round trip joins the intended child once through the real relay',
    () => _network(() async {
      final child = _child('a' * 32);
      final invitationCode = await MilkFamilySync.invite(child, relay.url, 0);
      final scanned = MilkInvitationQr.parse(
        MilkInvitationQr(relay.url, invitationCode).encode(),
      );
      SharedPreferences.setMockInitialValues({});
      await MilkFamilySync.join(scanned.address, scanned.code);
      expect((await MilkFamilySync.childProfile())['id'], child.id);
      await expectLater(
        MilkFamilySync.join(scanned.address, scanned.code),
        throwsA(
          isA<MilkSyncException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
    }),
  );
}
