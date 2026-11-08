import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:town_pass/service/milk_invitation_qr.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/page/city_service/milk_service_view.dart';
import 'package:town_pass/service/milk_family_store.dart';

const _childId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, dynamic> _profile({
  List<Map<String, dynamic>> records = const [],
}) => {'id': _childId, 'alias': '孩子1', 'records': records};

void _childPreferences(Map<String, dynamic> cached) {
  SharedPreferences.setMockInitialValues({
    'milk_sync_child_url': 'http://127.0.0.1:8765',
    'milk_sync_child_token': 'test-child-token',
    'milk_child_local_name': '小明',
    'milk_child_cache': jsonEncode(cached),
  });
}

void _parentPreferences() {
  SharedPreferences.setMockInitialValues({
    MilkFamilyStore.key: jsonEncode([
      {
        'id': _childId,
        'number': '0123456789012345',
        'name': '小明',
        'school': '測試國小',
        'records': [],
      },
    ]),
    'milk_sync_parent_url': 'http://127.0.0.1:8765',
    'milk_sync_parent_token': 'test-parent-token',
    'milk_sync_shared_ids': [_childId],
  });
}

class _Reply {
  const _Reply(this.body, {this.status = 200});
  final int status;
  final Map<String, dynamic> body;
}

class _Relay {
  _Relay(this.respond);
  final FutureOr<_Reply> Function(_Request request) respond;
  final List<_Request> requests = [];

  int count(String method, String path) => requests
      .where((request) => request.method == method && request.uri.path == path)
      .length;

  Future<HttpClientResponse> send(_Request request) async {
    requests.add(request);
    final reply = await respond(request);
    return _Response(reply);
  }

  Future<void> run(Future<void> Function() action) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await HttpOverrides.runZoned(
        action,
        createHttpClient: (_) => _Client(this),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }
}

class _Client extends Fake implements HttpClient {
  _Client(this.relay);
  final _Relay relay;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _Request(relay, 'GET', url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) async =>
      _Request(relay, 'POST', url);
  @override
  void close({bool force = false}) {}
}

class _Headers extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  set contentType(ContentType? value) {}
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.relay, this.method, this.uri);
  final _Relay relay;
  @override
  final String method;
  @override
  final Uri uri;
  @override
  final HttpHeaders headers = _Headers();
  @override
  int contentLength = -1;
  final body = StringBuffer();
  @override
  void write(Object? object) => body.write(object);
  @override
  void add(List<int> data) => body.write(utf8.decode(data));
  @override
  Future<HttpClientResponse> close() => relay.send(this);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.reply);
  final _Reply reply;
  @override
  int get statusCode => reply.status;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(utf8.encode(jsonEncode(reply.body))).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _show(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(440, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MaterialApp(home: MilkServiceView()));
  await tester.pumpAndSettle();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  final scenarios = <String, Future<void> Function(WidgetTester)>{};
  void scenario(String name, Future<void> Function(WidgetTester) action) {
    scenarios[name] = action;
  }

  scenario('revoked child hides cached status and opens a new invitation', (
    tester,
  ) async {
    _childPreferences(_profile());
    final relay = _Relay((_) => const _Reply({'error': '連線已失效'}, status: 401));
    await relay.run(() async {
      await _show(tester);
      expect(find.textContaining('已被家長解除'), findsOneWidget);
      expect(find.text('這週還有 1 瓶'), findsNothing);
      expect(find.text('我拿到了'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('milk_child_cache'), isNull);

      await tester.tap(find.text('輸入新邀請碼'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '邀請碼'), findsOneWidget);
      expect(prefs.getString('milk_sync_child_token'), isNull);
      await _dispose(tester);
    });
  });

  scenario('offline child labels cached data and cannot record', (
    tester,
  ) async {
    _childPreferences(_profile());
    final relay = _Relay((_) => throw const SocketException('offline'));
    await relay.run(() async {
      await _show(tester);
      expect(find.textContaining('以下是上次同步的資料'), findsOneWidget);
      expect(find.text('這週還有 1 瓶'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('我拿到了'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(relay.count('POST', '/v1/child/record'), 0);
      await _dispose(tester);
    });
  });

  scenario('child sees its own dated redemption history', (tester) async {
    final child = _profile(
      records: [
        {'week': '2026-10-26', 'product': '豆漿', 'date': '2026/10/28 09:30'},
      ],
    );
    _childPreferences(child);
    final relay = _Relay((_) => _Reply({'child': child}));
    await relay.run(() async {
      await _show(tester);
      await tester.ensureVisible(find.text('我的兌領紀錄'));
      await tester.pumpAndSettle();
      expect(find.text('豆漿'), findsOneWidget);
      expect(find.text('2026/10/28 09:30'), findsOneWidget);
      expect(find.textContaining('0123456789012345'), findsNothing);
      await _dispose(tester);
    });
  });

  for (final reset in [false, true]) {
    scenario(
      'parent ${reset ? 'reset' : 'removal'} pauses polling throughout revocation',
      (tester) async {
        _parentPreferences();
        final revoked = Completer<_Reply>();
        final relay = _Relay((request) {
          if (request.uri.path == '/v1/parent/revoke') return revoked.future;
          return _Reply({
            'children': [_profile()],
          });
        });
        await relay.run(() async {
          await _show(tester);
          expect(relay.count('GET', '/v1/parent/children'), 1);
          await tester.tap(find.byTooltip('家庭設定'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(reset ? '清除資料' : '移除子女'));
          await tester.tap(find.text(reset ? '清除資料' : '移除子女'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(reset ? '清除並重設' : '移除'));
          await tester.pumpAndSettle();
          expect(relay.count('POST', '/v1/parent/revoke'), 1);

          await tester.pump(const Duration(seconds: 6));
          expect(relay.count('GET', '/v1/parent/children'), 1);
          revoked.complete(const _Reply({'ok': true}));
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 6));
          await tester.pumpAndSettle();
          expect(find.text('開始設定學生資料'), findsOneWidget);
          expect(find.text('小明'), findsNothing);
          expect(await MilkFamilyStore.load(), isEmpty);
          expect(relay.count('GET', '/v1/parent/children'), 1);
          await _dispose(tester);
        });
      },
    );
  }

  scenario('child polling and record submission cannot overwrite each other', (
    tester,
  ) async {
    final empty = _profile();
    _childPreferences(empty);
    final delayedGet = Completer<_Reply>();
    final delayedPost = Completer<_Reply>();
    var gets = 0;
    final relay = _Relay((request) {
      if (request.method == 'POST') return delayedPost.future;
      gets++;
      return gets == 1 ? _Reply({'child': empty}) : delayedGet.future;
    });
    await relay.run(() async {
      await _show(tester);
      expect(find.text('我拿到了'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      expect(gets, 2);
      expect(find.text('同步中…'), findsOneWidget);
      final syncingButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('同步中…'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(syncingButton.onPressed, isNull);
      // A held GET prevents a record form/POST from racing its old response.
      expect(find.text('選擇品項'), findsNothing);
      expect(relay.count('POST', '/v1/child/record'), 0);
      delayedGet.complete(_Reply({'child': empty}));
      await tester.pumpAndSettle();

      await tester.tap(find.text('我拿到了'));
      await tester.pumpAndSettle();
      expect(find.text('選擇品項'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      expect(gets, 2);
      await tester.tap(find.text('豆漿'));
      await tester.tap(find.text('我已經拿到了'));
      await tester.pumpAndSettle();
      expect(relay.count('POST', '/v1/child/record'), 1);
      await tester.pump(const Duration(seconds: 6));
      expect(gets, 2);
      final posted = jsonDecode(relay.requests.last.body.toString()) as Map;
      delayedPost.complete(
        _Reply({
          'child': _profile(
            records: [Map<String, dynamic>.from(posted['record'] as Map)],
          ),
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('這週已記錄'), findsNWidgets(2));
      final prefs = await SharedPreferences.getInstance();
      final cached = jsonDecode(prefs.getString('milk_child_cache')!) as Map;
      expect((cached['records'] as List).single['product'], '豆漿');
      expect(tester.takeException(), isNull);
      await _dispose(tester);
    });
  });

  scenario(
    'parent displays an expiring QR and child scan fills the join form',
    (tester) async {
      _parentPreferences();
      final relay = _Relay((request) {
        if (request.uri.path == '/v1/parent/invitations') {
          return const _Reply({'code': 'ABCDEFGHJKLM'});
        }
        if (request.method == 'GET') {
          return _Reply({
            'children': [_profile()],
          });
        }
        return const _Reply({});
      });
      await relay.run(() async {
        await _show(tester);
        await tester.tap(find.byTooltip('家庭設定'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('邀請孩子'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('產生邀請碼'));
        await tester.tap(find.text('產生邀請碼'));
        await tester.pumpAndSettle();
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.text('ABCDEFGHJKLM'), findsOneWidget);
        await tester.pump(const Duration(minutes: 10));
        await tester.pumpAndSettle();
        expect(find.byType(QrImageView), findsNothing);
        expect(find.textContaining('邀請碼已過期'), findsOneWidget);
        await _dispose(tester);

        SharedPreferences.setMockInitialValues({});
        await _show(tester);
        await tester.tap(find.text('開始設定'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('我是孩子，輸入邀請碼'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('掃描家長邀請 QR Code'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('掃描家長邀請 QR Code'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        expect(find.text('掃描家庭邀請碼'), findsOneWidget);
        final scanner = tester.widget<MobileScanner>(
          find.byType(MobileScanner),
        );
        scanner.onDetect!(
          BarcodeCapture(
            barcodes: [
              Barcode(
                rawValue: const MilkInvitationQr(
                  'http://192.168.1.20:8765',
                  'ABCDEFGHJKLM',
                ).encode(),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('進階連線設定'));
        await tester.pumpAndSettle();
        final fields = tester
            .widgetList<TextField>(find.byType(TextField))
            .toList();
        expect(fields[0].controller!.text, 'http://192.168.1.20:8765');
        expect(fields[1].controller!.text, 'ABCDEFGHJKLM');
        expect(find.text('加入'), findsOneWidget);
        await _dispose(tester);
      });
    },
  );

  // Reminder scheduling serializes work in a static Future. Keep these scenarios
  // on one fake clock so a completed queue from a disposed test zone cannot
  // strand the next scenario. Widgets and preferences are reset for each flow.
  testWidgets('family session recovery and serialized synchronization flows', (
    tester,
  ) async {
    for (final entry in scenarios.entries) {
      try {
        await entry.value(tester);
      } catch (error, stack) {
        Error.throwWithStackTrace(StateError('${entry.key}: $error'), stack);
      }
    }
  });
}
