import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/page/city_service/milk_redemption_demo_view.dart';
import 'package:town_pass/service/milk_redemption_demo.dart';

class _DemoRelay {
  final children = <Map<String, dynamic>>[
    {
      'id': 'a' * 32,
      'alias': '孩子1',
      'cardRef': 'DEMO-CARD-01',
      'records': <Map<String, dynamic>>[],
    },
    {
      'id': 'b' * 32,
      'alias': '孩子2',
      'cardRef': 'DEMO-CARD-02',
      'records': <Map<String, dynamic>>[],
    },
  ];
  final events = <Map<String, dynamic>>[];
  bool failNext = false;

  Future<HttpClientResponse> send(_Request request) async {
    if (request.uri.path == '/v1/demo/families') {
      return _Response({'parentToken': 'demo-token', 'children': children});
    }
    if (request.uri.path == '/v1/parent/children') {
      return _Response({'children': children});
    }
    if (request.uri.path != '/v1/demo/transactions') {
      throw StateError('Unexpected demo request');
    }
    final event = jsonDecode(request.body.toString()) as Map<String, dynamic>;
    events.add(event);
    if (failNext) {
      failNext = false;
      throw const SocketException('temporary network failure');
    }
    final child = children.singleWhere((c) => c['cardRef'] == event['cardRef']);
    final records = child['records'] as List;
    final duplicate = records.isNotEmpty;
    if (!duplicate) {
      final now = DateTime.now().toUtc().add(const Duration(hours: 8));
      final week = DateTime.utc(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1))
          .toIso8601String()
          .substring(0, 10);
      records.add({
        'week': week,
        'product': event['product'],
        'date': '2026/11/08 10:00',
        'source': 'demo_transaction',
        'transactionId': event['transactionId'],
        'confirmedAt': '2026-11-08T10:00:00+08:00',
      });
    }
    return _Response({
      'result': duplicate ? 'duplicate_transaction' : 'accepted',
      'child': child,
    });
  }

  Future<void> run(Future<void> Function() action) =>
      HttpOverrides.runZoned(action, createHttpClient: (_) => _Client(this));
}

class _Client extends Fake implements HttpClient {
  _Client(this.relay);
  final _DemoRelay relay;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(relay, url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) async => _Request(relay, url);
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
  _Request(this.relay, this.uri);
  final _DemoRelay relay;
  @override
  final Uri uri;
  @override
  final HttpHeaders headers = _Headers();
  @override
  int contentLength = -1;
  final body = StringBuffer();
  @override
  void add(List<int> data) => body.write(utf8.decode(data));
  @override
  Future<HttpClientResponse> close() => relay.send(this);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.value);
  final Map<String, dynamic> value;
  @override
  int get statusCode => 200;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(utf8.encode(jsonEncode(value))).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _show(WidgetTester tester) async {
  if (await MilkRedemptionDemo.savedUrl() == null) {
    await MilkRedemptionDemo.open("http://127.0.0.1:8766");
  }
  await tester.binding.setSurfaceSize(const Size(440, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MaterialApp(home: MilkRedemptionDemoView()));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'a previous-week event cannot make the displayed product differ from the new transaction',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        MilkRedemptionDemo.preferenceKey: jsonEncode({
          'url': 'http://127.0.0.1:8766',
          'token': 'demo-token',
          'events': {
            'DEMO-CARD-01': {
              'transactionId': '1' * 32,
              'cardRef': 'DEMO-CARD-01',
              'product': '豆漿',
              'week': '2000-01-03',
            },
          },
        }),
      });
      final relay = _DemoRelay();
      await relay.run(() async {
        await _show(tester);
        final selected = tester.widget<Semantics>(
          find.byKey(const Key('demo-drink-鮮奶')),
        );
        expect(selected.properties.checked, isTrue);
        const displayedProduct = '鮮奶';
        await tester.ensureVisible(find.text('領取 1 瓶鮮奶'));
        await tester.tap(find.text('領取 1 瓶鮮奶'));
        await tester.pumpAndSettle();
        expect(relay.events.single['product'], displayedProduct);
        expect(relay.events.single['transactionId'], isNot('1' * 32));
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );

  testWidgets(
    'labelled demo records the selected child and prevents repeated transactions',
    (tester) async {
      final relay = _DemoRelay();
      await relay.run(() async {
        await _show(tester);
        expect(find.text('每週一瓶，鮮奶與豆漿自由選擇'), findsOneWidget);
        expect(find.text('本週尚未領取'), findsNWidgets(2));
        await tester.ensureVisible(find.text('豆漿'));
        await tester.tap(find.text('豆漿'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('領取 1 瓶豆漿'));
        await tester.tap(find.text('領取 1 瓶豆漿'));
        await tester.pumpAndSettle();
        expect(find.text('本週已領取'), findsNWidgets(2));
        expect(find.text('本週尚未領取'), findsOneWidget);
        expect(find.textContaining('領取完成'), findsOneWidget);
        expect(find.text('豆漿 · 已領取'), findsOneWidget);
        expect(relay.children.last['records'], isEmpty);
        expect((relay.children.first['records'] as List).length, 1);

        await tester.tap(find.byTooltip('展示設定'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('重送同筆交易（測試防重複）'));
        await tester.tap(find.text('重送同筆交易（測試防重複）'));
        await tester.pumpAndSettle();
        expect(find.text('這筆領取已完成。'), findsOneWidget);
        expect(relay.events.length, 2);
        expect(relay.events.first, relay.events.last);
        expect((relay.children.first['records'] as List).length, 1);
        await tester.tap(find.text('完成'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('孩子2'));
        await tester.tap(find.text('孩子2'));
        await tester.pumpAndSettle();
        expect(find.text('還沒有領取紀錄'), findsOneWidget);
        expect(find.text('豆漿 · 已領取'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );

  testWidgets(
    'failed transaction stays unconfirmed and retry sends the same event',
    (tester) async {
      final relay = _DemoRelay()..failNext = true;
      await relay.run(() async {
        await _show(tester);
        await tester.ensureVisible(find.text('領取 1 瓶鮮奶'));
        await tester.tap(find.text('領取 1 瓶鮮奶'));
        await tester.pumpAndSettle();
        expect(find.text('暫時無法確認，請稍後再試。'), findsOneWidget);
        expect(find.textContaining('領取完成'), findsNothing);
        expect(find.text('本週已領取'), findsNothing);
        expect(find.text('本週尚未領取'), findsNWidgets(2));
        expect(
          relay.children.every((c) => (c['records'] as List).isEmpty),
          isTrue,
        );
        await tester.ensureVisible(find.text('重試原交易'));
        await tester.tap(find.text('重試原交易'));
        await tester.pumpAndSettle();
        expect(find.textContaining('領取完成'), findsOneWidget);
        expect(relay.events.length, 2);
        expect(relay.events.first, relay.events.last);
        expect((relay.children.first['records'] as List).length, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );
}
