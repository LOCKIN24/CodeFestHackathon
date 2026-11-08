import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:town_pass/page/city_service/milk_service_view.dart';
import 'package:town_pass/service/milk_family_store.dart';
import 'package:town_pass/service/milk_redemption_demo.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/milk_feature_theme.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/page/city_service/milk_redemption_demo_view.dart';

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

void main() {
  setUpAll(() async {
    final loader = FontLoader('PingFangTC')
      ..addFont(rootBundle.load('fonts/PingFangTC-Regular.otf'));
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final dark in [false, true]) {
    for (final demo in [false, true]) {
      testWidgets(
        'render ${demo ? 'demo' : 'parent'} ${dark ? 'dark' : 'light'} small large text',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(360, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          SharedPreferences.setMockInitialValues({
            MilkFamilyStore.key: jsonEncode([
              {
                'id': 'c' * 32,
                'name': '測試孩子',
                'school': '測試學校',
                'number': '0000000000000000',
                'records': [],
              },
              {
                'id': 'd' * 32,
                'name': '另一位孩子',
                'school': '測試學校',
                'number': '0000000000000001',
                'records': [],
              },
            ]),
          });
          final relay = _DemoRelay();
          await relay.run(() async {
            if (demo) await MilkRedemptionDemo.open("http://127.0.0.1:8766");
            final boundary = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData.light(),
                darkTheme: ThemeData.dark(),
                themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                home: RepaintBoundary(
                  key: boundary,
                  child: MediaQuery(
                    data: const MediaQueryData(
                      size: Size(360, 800),
                      textScaler: TextScaler.linear(1.4),
                    ),
                    child: demo
                        ? const MilkRedemptionDemoView()
                        : const MilkServiceView(),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final featureContext = tester.element(
              find.byType(MilkFeatureTheme).first,
            );
            // Inspect the actual applied descendant theme, not the system theme.
            final scaffold = tester.element(find.byType(Scaffold).first);
            expect(Theme.of(scaffold).colorScheme.surface, TPColors.white);
            expect(
              Theme.of(scaffold).dialogTheme.backgroundColor,
              TPColors.white,
            );
            expect(
              Theme.of(scaffold).radioTheme.fillColor!
                  .resolve({WidgetState.selected}),
              TPColors.primary700,
            );
            expect(
              Theme.of(scaffold).radioTheme.backgroundColor!.resolve({}),
              Colors.transparent,
            );
            expect(featureContext.mounted, isTrue);
            expect(Theme.of(scaffold).iconTheme.color, TPColors.grayscale700);
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 2);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory('../screenshots')
                ..createSync(recursive: true);
              File(
                '${dir.path}/${demo ? 'demo' : 'parent'}-${dark ? 'dark' : 'light'}.png',
              ).writeAsBytesSync(data!.buffer.asUint8List());
              image.dispose();
            });
            if (demo) {
              await tester.ensureVisible(
                find.byKey(const ValueKey('demo-drink-豆漿')),
              );
              await tester.tap(find.byKey(const ValueKey('demo-drink-豆漿')));
              await tester.pumpAndSettle();
              await tester.ensureVisible(find.text('領取 1 瓶豆漿'));
              await tester.tap(find.text('領取 1 瓶豆漿'));
              await tester.pumpAndSettle();
              expect(
                find.widgetWithText(FilledButton, '本週已領取'),
                findsOneWidget,
              );
              expect(relay.events.single['product'], '豆漿');
              await tester.tap(find.byTooltip('展示設定'));
              await tester.pumpAndSettle();
              expect(
                tester
                    .widget<AlertDialog>(find.byType(AlertDialog))
                    .backgroundColor,
                TPColors.white,
              );
              expect(tester.takeException(), isNull);
              await tester.tap(find.text('完成'));
              await tester.pumpAndSettle();
            } else {
              await tester.tap(find.byTooltip('資格說明'));
              await tester.pumpAndSettle();
              expect(
                tester
                    .widget<AlertDialog>(find.byType(AlertDialog))
                    .backgroundColor,
                TPColors.white,
              );
              await tester.tap(find.text('我知道了'));
              await tester.pumpAndSettle();
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          });
        },
      );
    }
  }
}
