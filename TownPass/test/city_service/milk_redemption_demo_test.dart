import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/service/milk_family_sync.dart';
import 'package:town_pass/service/milk_redemption_demo.dart';

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

  static Future<_Relay> start({
    bool enabled = true,
    bool dropFirst = false,
  }) async {
    final process = await Process.start('python3', [
      '-u',
      '-c',
      'import server, socket\n'
          'class TestHandler(server.Handler):\n'
          '    drop_next = ${dropFirst ? 'True' : 'False'}\n'
          '    def reply(self, code, value):\n'
          '        if self.path == "/v1/demo/transactions" and code == 200 and TestHandler.drop_next:\n'
          '            TestHandler.drop_next = False\n'
          '            self.close_connection = True\n'
          '            self.connection.shutdown(socket.SHUT_RDWR)\n'
          '            self.connection.close()\n'
          '            return\n'
          '        return super().reply(code, value)\n'
          'relay = server.ThreadingHTTPServer(("127.0.0.1", 0), TestHandler)\n'
          'relay.demo_transactions_enabled = ${enabled ? 'True' : 'False'}\n'
          'print(relay.server_address[1], flush=True)\n'
          'relay.serve_forever()\n',
    ], workingDirectory: 'tools/milk_demo_server');
    process.stderr.drain<void>();
    final line = await process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first
        .timeout(const Duration(seconds: 10));
    return _Relay(process, int.parse(line));
  }

  Future<void> stop() async {
    process.kill();
    await process.exitCode.timeout(const Duration(seconds: 5));
  }
}

const _sentinels = <String, Object>{
  'milk_family_v2':
      '[{"id":"real-student-sentinel","number":"private-test-card"}]',
  'milk_sync_parent_token': 'existing-parent-sentinel',
  'milk_sync_child_token': 'existing-child-sentinel',
  'milk_child_cache': '{"alias":"existing-child-cache"}',
  'milk_selected_child_v2': 'real-student-sentinel',
};

Future<Map<String, dynamic>> _http(
  MilkDemoSession session,
  String path, {
  Map<String, dynamic>? body,
  String? token,
}) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse('${session.url}$path');
    final request = body == null
        ? await client.getUrl(uri)
        : await client.postUrl(uri);
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${token ?? session.token}',
    );
    if (body != null) {
      final bytes = utf8.encode(jsonEncode(body));
      request.contentLength = bytes.length;
      request.headers.contentType = ContentType.json;
      request.add(bytes);
    }
    final response = await request.close();
    expect(response.statusCode, lessThan(400));
    return jsonDecode(await response.transform(utf8.decoder).join())
        as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Relay relay;
  setUp(() async {
    SharedPreferences.setMockInitialValues(_sentinels);
    relay = await _Relay.start();
  });
  tearDown(() async => relay.stop());

  test(
    'server transaction updates only its demo child with server confirmation metadata',
    () => _network(() async {
      final session = await MilkRedemptionDemo.open(relay.url);
      expect(session.children.length, 2);
      final result = await MilkRedemptionDemo.redeem(
        session,
        'DEMO-CARD-02',
        '豆漿',
      );
      expect(result.result, 'accepted');
      expect(result.child['id'], session.children[1]['id']);
      final record = (result.child['records'] as List).single as Map;
      expect(record['source'], 'demo_transaction');
      expect(record['product'], '豆漿');
      expect(record['transactionId'], matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(record['confirmedAt'], endsWith('+08:00'));
      final confirmed = DateTime.parse(record['confirmedAt'] as String);
      expect(
        DateTime.now().toUtc().difference(confirmed).abs(),
        lessThan(const Duration(seconds: 10)),
      );
      final taipei = confirmed.toUtc().add(const Duration(hours: 8));
      final monday = DateTime.utc(
        taipei.year,
        taipei.month,
        taipei.day,
      ).subtract(Duration(days: taipei.weekday - 1));
      expect(record['week'], monday.toIso8601String().substring(0, 10));
      final updated = await MilkRedemptionDemo.refresh(session);
      expect(updated.children.first['records'], isEmpty);
      expect(updated.children.last['records'], [record]);
    }),
  );

  test(
    'reopen and repeat keep the transaction ID and original product',
    () => _network(() async {
      final session = await MilkRedemptionDemo.open(relay.url);
      final first = await MilkRedemptionDemo.redeem(
        session,
        'DEMO-CARD-01',
        '鮮奶',
      );
      final event = await MilkRedemptionDemo.lastEvent(session, 'DEMO-CARD-01');
      final reopened = await MilkRedemptionDemo.open('${relay.url}/');
      expect(reopened.token, session.token);
      final repeated = await MilkRedemptionDemo.redeem(
        reopened,
        'DEMO-CARD-01',
        '豆漿',
        repeat: true,
      );
      expect(repeated.result, 'duplicate_transaction');
      expect(repeated.child['records'], first.child['records']);
      expect(
        (await MilkRedemptionDemo.lastEvent(
          reopened,
          'DEMO-CARD-01',
        ))!['transactionId'],
        event!['transactionId'],
      );
      expect((repeated.child['records'] as List).single['product'], '鮮奶');
      final implicitRetry = await MilkRedemptionDemo.redeem(
        reopened,
        'DEMO-CARD-01',
        '豆漿',
      );
      expect(implicitRetry.result, 'duplicate_transaction');
    }),
  );

  test(
    'a lost success response is safely retried after reopening',
    () => _network(() async {
      await relay.stop();
      relay = await _Relay.start(dropFirst: true);
      final session = await MilkRedemptionDemo.open(relay.url);
      await expectLater(
        MilkRedemptionDemo.redeem(session, 'DEMO-CARD-02', '鮮奶'),
        throwsA(isA<Exception>()),
      );
      final pending = await MilkRedemptionDemo.lastEvent(
        session,
        'DEMO-CARD-02',
      );
      expect(pending, isNotNull);
      final reopened = await MilkRedemptionDemo.open(relay.url);
      expect((reopened.children.last['records'] as List).length, 1);
      final replay = await MilkRedemptionDemo.redeem(
        reopened,
        'DEMO-CARD-02',
        '豆漿',
        repeat: true,
      );
      expect(replay.result, 'duplicate_transaction');
      expect(
        (replay.child['records'] as List).single['transactionId'],
        pending!['transactionId'],
      );
      expect((replay.child['records'] as List).single['product'], '鮮奶');
    }),
  );

  test(
    'opening, redeeming and rebuilding preserve ordinary student and account preferences',
    () => _network(() async {
      final first = await MilkRedemptionDemo.open(relay.url);
      await MilkRedemptionDemo.redeem(first, 'DEMO-CARD-01', '鮮奶');
      final fresh = await MilkRedemptionDemo.open(relay.url, fresh: true);
      expect(fresh.token, isNot(first.token));
      expect(
        fresh.children.map((c) => c['id']),
        isNot(first.children.map((c) => c['id'])),
      );
      expect(
        fresh.children.every((c) => (c['records'] as List).isEmpty),
        isTrue,
      );
      expect(
        (await MilkRedemptionDemo.refresh(first)).children.first['records'],
        hasLength(1),
      );
      final prefs = await SharedPreferences.getInstance();
      for (final entry in _sentinels.entries) {
        expect(prefs.get(entry.key), entry.value, reason: entry.key);
      }
      expect(prefs.getKeys(), {
        ..._sentinels.keys,
        MilkRedemptionDemo.preferenceKey,
      });
      expect(await MilkRedemptionDemo.lastEvent(fresh, 'DEMO-CARD-01'), isNull);
      expect(await MilkRedemptionDemo.lastEvent(first, 'DEMO-CARD-01'), isNull);
    }),
  );

  test(
    'fresh rebuild recovers corrupt demo preferences without clearing ordinary data',
    () => _network(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(MilkRedemptionDemo.preferenceKey, '{broken json');
      final fresh = await MilkRedemptionDemo.open(relay.url, fresh: true);
      expect(fresh.children, hasLength(2));
      for (final entry in _sentinels.entries) {
        expect(prefs.get(entry.key), entry.value);
      }
      expect(
        jsonDecode(prefs.getString(MilkRedemptionDemo.preferenceKey)!)['token'],
        fresh.token,
      );
    }),
  );

  test(
    'normal invitation and child profile receive the simulated server event',
    () => _network(() async {
      final session = await MilkRedemptionDemo.open(relay.url);
      final invite = await _http(
        session,
        '/v1/parent/invitations',
        body: {'childId': session.children.last['id']},
      );
      final joined = await _http(
        session,
        '/v1/join',
        body: {'code': invite['code']},
      );
      final result = await MilkRedemptionDemo.redeem(
        session,
        'DEMO-CARD-02',
        '豆漿',
      );
      final profile = await _http(
        session,
        '/v1/child/profile',
        token: joined['childToken'] as String,
      );
      expect(profile['child']['records'], result.child['records']);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'milk_sync_child_token',
        ),
        _sentinels['milk_sync_child_token'],
      );
    }),
  );

  test(
    'expired session and disabled demo return typed errors',
    () => _network(() async {
      final session = await MilkRedemptionDemo.open(relay.url);
      await expectLater(
        MilkRedemptionDemo.refresh(
          MilkDemoSession(session.url, 'expired-token', session.children),
        ),
        throwsA(
          isA<MilkSyncException>().having((e) => e.statusCode, 'status', 401),
        ),
      );
      await relay.stop();
      relay = await _Relay.start(enabled: false);
      await expectLater(
        MilkRedemptionDemo.open(relay.url, fresh: true),
        throwsA(
          isA<MilkSyncException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString(MilkRedemptionDemo.preferenceKey)!)['token'],
        session.token,
      );
    }),
  );
}
