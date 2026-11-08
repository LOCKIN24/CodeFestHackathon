import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/page/city_service/milk_redemption_demo_view.dart';
import 'package:town_pass/page/city_service/milk_reminder_preview.dart';
import 'package:town_pass/page/city_service/milk_service_view.dart';
import 'package:town_pass/service/milk_family_store.dart';
import 'package:town_pass/service/milk_family_sync.dart';
import 'package:town_pass/service/milk_reminder_target.dart';
import 'package:town_pass/service/milk_redemption_demo.dart';

final _idA = 'a' * 32;
final _idB = 'b' * 32;
const _previewKey = Key('milk-reminder-preview');

List<Map<String, dynamic>> _localChildren() => [
  {
    'id': _idA,
    'number': '0123456789012345',
    'name': '小明',
    'school': '中正國小',
    'records': <Map<String, dynamic>>[],
  },
  {
    'id': _idB,
    'number': '1234567890123456',
    'name': '小美',
    'school': '大同國小',
    'records': <Map<String, dynamic>>[],
  },
];

class _ReminderRelay {
  final profile = <String, dynamic>{
    'id': _idA,
    'alias': '孩子1',
    'records': <Map<String, dynamic>>[],
  };
  final demoChildren = <Map<String, dynamic>>[
    {
      'id': _idA,
      'alias': '孩子1',
      'cardRef': 'DEMO-CARD-01',
      'records': <Map<String, dynamic>>[],
    },
    {
      'id': _idB,
      'alias': '孩子2',
      'cardRef': 'DEMO-CARD-02',
      'records': <Map<String, dynamic>>[],
    },
  ];
  final demoEvents = <Map<String, dynamic>>[];
  bool offline = false;

  Future<HttpClientResponse> send(_Request request) async {
    if (offline) throw const SocketException('test offline');
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body.toString()) as Map<String, dynamic>;
    switch (request.uri.path) {
      case '/v1/child/profile':
        return _Response({'child': profile});
      case '/v1/child/record':
        (profile['records'] as List).add(body['record']);
        return _Response({'child': profile});
      case '/v1/demo/families':
        return _Response({
          'parentToken': 'demo-test-token',
          'children': demoChildren,
        });
      case '/v1/parent/children':
        return _Response({'children': demoChildren});
      case '/v1/parent/revoke':
        return _Response({'ok': true});
      case '/v1/parent/record':
        final child = demoChildren.singleWhere(
          (c) => c['id'] == body['childId'],
        );
        final record = Map<String, dynamic>.from(body['record'] as Map);
        final records = child['records'] as List;
        if (!records.any((r) => r['week'] == record['week'])) {
          records.add(record);
        }
        return _Response({'child': child});
      case '/v1/demo/transactions':
        demoEvents.add(body);
        final child = demoChildren.singleWhere(
          (c) => c['cardRef'] == body['cardRef'],
        );
        (child['records'] as List).add({
          'week': MilkReminderTarget.weekOf(taipeiNow()),
          'product': body['product'],
          'date': '2026/11/08 10:00',
          'source': 'demo_transaction',
          'transactionId': body['transactionId'],
          'confirmedAt': '2026-11-08T10:00:00+08:00',
        });
        return _Response({'result': 'accepted', 'child': child});
      default:
        throw StateError('Unexpected reminder test request');
    }
  }

  Future<void> run(Future<void> Function() action) =>
      HttpOverrides.runZoned(action, createHttpClient: (_) => _Client(this));
}

class _Client extends Fake implements HttpClient {
  _Client(this.relay);
  final _ReminderRelay relay;
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
  final _ReminderRelay relay;
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

Future<void> _show(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(440, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

Future<void> _preview(WidgetTester tester) async {
  if (find.byKey(_previewKey).evaluate().isEmpty) {
    await tester.tap(
      find.byTooltip(
        find.byTooltip('家庭設定').evaluate().isNotEmpty ? '家庭設定' : '展示設定',
      ),
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.byKey(_previewKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(_previewKey));
  await tester.pumpAndSettle();
  expect(find.text('提醒預覽'), findsOneWidget);
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  debugDefaultTargetPlatformOverride = null;
  expect(tester.takeException(), isNull);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<void> stackedRouteScenario(WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({
      MilkFamilyStore.key: jsonEncode(_localChildren()),
      MilkFamilyStore.selectedKey: _idA,
      'milk_sync_parent_url': 'http://127.0.0.1:8765',
      'milk_sync_parent_token': 'parent-test-token',
      'milk_sync_shared_ids': [_idA, _idB],
    });
    final relay = _ReminderRelay();
    await relay.run(() async {
      await _show(tester, const MilkServiceView());
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(const Key('milk-child-selector')),
            )
            .items!
            .map((item) => item.value),
        contains(_idB),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => MilkServiceView(
              reminderTarget: MilkReminderTarget(
                childId: _idB,
                name: '',
                role: 'parent',
                week: MilkReminderTarget.weekOf(taipeiNow()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('大同國小'), findsOneWidget);

      // Model completed edits on the notification-opened detail route. The
      // route below still holds its original A/B snapshot until it resumes.
      await MilkFamilySync.revoke(_idB);
      final localRecord = {
        'week': weekKey(taipeiNow()),
        'product': '豆漿',
        'date': '2026/11/08 10:00',
        'store': '只在本機保存的門市',
      };
      final childA = MilkChild.fromJson({
        ..._localChildren().first,
        'records': [localRecord],
      });
      final idC = 'c' * 32;
      final childC = MilkChild(
        id: idC,
        number: '2345678901234567',
        name: '小華',
        school: '信義國小',
      );
      await MilkFamilyStore.save([childA, childC]);
      // A newly received remote record forces the returning route to merge
      // and save. Without reloading the store first, that save resurrects B,
      // loses C, and discards A's newly committed local record.
      final remoteRecord = {
        'week': weekKey(taipeiNow().subtract(const Duration(days: 7))),
        'product': '鮮奶',
        'date': '2026/11/01 10:00',
      };
      (relay.demoChildren.first['records'] as List).add(remoteRecord);

      navigator.pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      final stored = await MilkFamilyStore.load();
      expect(stored.map((c) => c.id), unorderedEquals([_idA, idC]));
      final records = stored.singleWhere((c) => c.id == _idA).records;
      expect(
        records.singleWhere((r) => r['week'] == localRecord['week']),
        localRecord,
      );
      expect(
        records.singleWhere((r) => r['week'] == remoteRecord['week']),
        remoteRecord,
      );
      expect(stored.singleWhere((c) => c.id == idC).school, '信義國小');
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(const Key('milk-child-selector')),
            )
            .items!
            .map((item) => item.value),
        contains(idC),
      );
      expect(find.text('小美'), findsNothing);
      expect(relay.demoChildren.last['id'], _idB);
      await _close(tester);
    });
  }

  testWidgets(
    'parent reminders target one child and preserve committed family changes after Back',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        MilkFamilyStore.key: jsonEncode(_localChildren()),
        MilkFamilyStore.selectedKey: _idA,
      });
      await _show(tester, const MilkServiceView());
      await _preview(tester);
      expect(find.text('小明 本週鮮奶提醒'), findsOneWidget);
      expect(find.text('小美 本週鮮奶提醒'), findsOneWidget);
      await tester.tap(find.text('小美 本週鮮奶提醒'));
      await tester.pumpAndSettle();
      expect(find.text('大同國小'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(const Key('milk-child-selector')),
            )
            .value,
        _idB,
      );

      await tester.ensureVisible(find.text('我已領取，留下紀錄'));
      await tester.tap(find.text('我已領取，留下紀錄'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('豆漿'));
      await tester.tap(find.text('我已經拿到了'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString(MilkFamilyStore.key)!) as List;
      expect(saved.first['records'], isEmpty);
      expect((saved.last['records'] as List).single['product'], '豆漿');

      await _preview(tester);
      expect(find.text('小明 本週鮮奶提醒'), findsOneWidget);
      expect(find.text('小美 本週鮮奶提醒'), findsNothing);
      await _close(tester);
      // Keep both store-writing parent scenarios on one widget-test clock.
      await stackedRouteScenario(tester);
    },
  );

  testWidgets(
    'child preview exposes only its own profile and clears after recording',
    (tester) async {
      final local = jsonEncode(_localChildren());
      SharedPreferences.setMockInitialValues({
        MilkFamilyStore.key: local,
        'milk_sync_child_url': 'http://127.0.0.1:8765',
        'milk_sync_child_token': 'child-test-token',
        'milk_child_local_name': '兒童小明',
      });
      final relay = _ReminderRelay();
      await relay.run(() async {
        await _show(tester, const MilkServiceView());
        await _preview(tester);
        expect(find.text('兒童小明 本週鮮奶提醒'), findsOneWidget);
        expect(find.text('小美 本週鮮奶提醒'), findsNothing);
        expect(find.textContaining('1234567890123456'), findsNothing);
        await tester.tap(find.text('兒童小明 本週鮮奶提醒'));
        await tester.pumpAndSettle();
        expect(find.text('嗨，兒童小明！'), findsOneWidget);
        await tester.ensureVisible(find.text('我拿到了'));
        await tester.tap(find.text('我拿到了'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('我已經拿到了'));
        await tester.pumpAndSettle();
        expect((relay.profile['records'] as List), hasLength(1));
        await _preview(tester);
        expect(find.text('本週的領取紀錄都已完成。'), findsOneWidget);
        expect(find.text('兒童小明 本週鮮奶提醒'), findsNothing);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(MilkFamilyStore.key), local);
        await _close(tester);
      });
    },
  );

  for (final offline in [false, true]) {
    testWidgets(
      'foreign child reminder hides the linked profile ${offline ? 'offline' : 'online'}',
      (tester) async {
        final relay = _ReminderRelay()..offline = offline;
        SharedPreferences.setMockInitialValues({
          'milk_sync_child_url': 'http://127.0.0.1:8765',
          'milk_sync_child_token': 'child-test-token',
          'milk_child_local_name': '兒童小明',
          'milk_child_cache': jsonEncode(relay.profile),
        });
        await relay.run(() async {
          await _show(
            tester,
            MilkServiceView(
              reminderTarget: MilkReminderTarget(
                childId: _idB,
                name: '',
                role: 'child',
                week: MilkReminderTarget.weekOf(taipeiNow()),
              ),
            ),
          );
          expect(find.byKey(_previewKey), findsNothing);
          expect(find.text('嗨，兒童小明！'), findsNothing);
          expect(find.text('我拿到了'), findsNothing);
          expect(find.text('這週還有 1 瓶'), findsNothing);
          expect(
            offline
                ? find.textContaining('還沒有可顯示的資料')
                : find.text('這則提醒不屬於目前連結的孩子。'),
            findsOneWidget,
          );
          await _close(tester);
        });
      },
    );
  }

  testWidgets(
    'demo reminder opens the intended card and refreshes pending rows on return',
    (tester) async {
      final local = jsonEncode(_localChildren());
      SharedPreferences.setMockInitialValues({MilkFamilyStore.key: local});
      final relay = _ReminderRelay();
      await relay.run(() async {
        if (await MilkRedemptionDemo.savedUrl() == null) {
          await MilkRedemptionDemo.open('http://127.0.0.1:8766');
        }
        await _show(tester, const MilkRedemptionDemoView());
        await _preview(tester);
        await tester.tap(find.text('孩子2 本週鮮奶提醒'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Semantics>(
                find.byKey(
                  ValueKey('demo-child-${relay.demoChildren.last['id']}'),
                ),
              )
              .properties
              .checked,
          isTrue,
        );

        await tester.ensureVisible(find.text('領取 1 瓶鮮奶'));
        await tester.tap(find.text('領取 1 瓶鮮奶'));
        await tester.pumpAndSettle();
        expect(relay.demoEvents.single['cardRef'], 'DEMO-CARD-02');
        expect(relay.demoChildren.first['records'], isEmpty);
        expect(relay.demoChildren.last['records'] as List, hasLength(1));
        await tester.pageBack();
        await tester.pumpAndSettle();
        await _preview(tester);
        expect(find.text('孩子1 本週鮮奶提醒'), findsOneWidget);
        expect(find.text('孩子2 本週鮮奶提醒'), findsNothing);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(MilkFamilyStore.key), local);
        await _close(tester);
      });
    },
  );

  testWidgets(
    'reminder preview remains usable on a narrow screen with large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: MilkReminderPreview(
              targets: [
                MilkReminderTarget(
                  childId: _idA,
                  name: '名字較長的第一位孩子',
                  role: 'parent',
                  week: '2026-11-02',
                ),
                MilkReminderTarget(
                  childId: _idB,
                  name: '名字較長的第二位孩子',
                  role: 'parent',
                  week: '2026-11-02',
                ),
              ],
              onOpen: (target) async => opened = target.childId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _preview(tester);
      final row = find.text('名字較長的第二位孩子 本週鮮奶提醒');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(opened, _idB);
      await _close(tester);
    },
  );
}
