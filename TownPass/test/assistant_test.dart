import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:town_pass/page/home/home_view.dart';
import 'package:town_pass/service/subscription_service.dart';
import 'package:town_pass/page/ai_assistant/assistant_view.dart';
import 'package:town_pass/page/ai_assistant/navigation_client.dart';

class FakeClient implements NavigationClient {
  FakeClient(this.answer);
  final Future<NavigationResult> Function(String) answer;
  @override
  Future<NavigationResult> request(String query) => answer(query);
}

NavigationResult result(String status, {String? reason}) => NavigationResult(
  {'intent': 'browse_or_navigate', 'action_allowed': false},
  {
    'status': status,
    'reason': reason,
    if (status == 'incomplete') ...{
      'feature_name': '活動訊息',
      'feature_id': 'activity_information',
      'missing': ['ActivityList'],
    },
  },
);
void main() {
  test('invalid response and action permissions fail closed', () {
    expect(
      () => NavigationResult.parse({
        'choice': {'intent': 'browse_or_navigate', 'action_allowed': true},
        'preview': {'status': 'preview'},
      }),
      throwsA(isA<NavigationException>()),
    );
    expect(
      () => NavigationResult.parse({'choice': {}, 'preview': {}}),
      throwsA(isA<NavigationException>()),
    );
    expect(LocalNavigationClient.isPrivateHost('8.8.8.8'), isFalse);
    expect(LocalNavigationClient.isPrivateHost('192.168.1.2'), isTrue);
    expect(LocalNavigationClient.isPrivateHost('example.com'), isFalse);
  });
  test('HTTP request, invalid JSON and timeout', () async {
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = <String>[];
    final subscription = server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      received.add('${request.headers.value('authorization')}:$body');
      expect(request.contentLength, utf8.encode(body).length);
      if (body.contains('timeout')) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        body.contains('invalid')
            ? 'not json'
            : jsonEncode({
                'choice': {
                  'intent': 'browse_or_navigate',
                  'action_allowed': false,
                },
                'preview': {
                  'status': 'incomplete',
                  'missing': ['ActivityList'],
                },
              }),
      );
      await request.response.close();
    });
    final http = HttpClient();
    final client = LocalNavigationClient(
      baseUrl: 'http://127.0.0.1:${server.port}',
      token: 'x' * 32,
      client: http,
      timeout: const Duration(milliseconds: 100),
    );
    try {
      final response = await client.request('activity');
      expect(response.preview['missing'], contains('ActivityList'));
      expect(received.first, contains('Bearer ${'x' * 32}'));
      expect(received.first, contains('activity'));
      await expectLater(
        client.request('invalid'),
        throwsA(isA<NavigationException>()),
      );
      await expectLater(
        client.request('timeout'),
        throwsA(
          isA<NavigationException>().having(
            (e) => e.message,
            'message',
            contains('逾時'),
          ),
        ),
      );
    } finally {
      http.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
      HttpOverrides.global = previousOverrides;
    }
  });
  testWidgets(
    'Home retains account control without the former assistant icon',
    (tester) async {
      Get.put(SubscriptionService());
      await tester.pumpWidget(
        GetMaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: const HomeView(),
        ),
      );
      await tester.pump();
      expect(find.byTooltip('AI 助理'), findsNothing);
      expect(find.bySemanticsLabel('帳戶'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
      Get.reset();
    },
  );
  testWidgets('opens chat and shows messages, loading and missing argument', (
    tester,
  ) async {
    final pending = Completer<NavigationResult>();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      AssistantView(client: FakeClient((_) => pending.future)),
                ),
              ),
              child: const Text('AI 助理'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('AI 助理'));
    await tester.pumpAndSettle();
    expect(find.text('可開啟安全頁面，不會執行服務操作'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('assistant-input')), '我要看活動');
    await tester.tap(find.byKey(const Key('assistant-send')));
    await tester.pump();
    expect(find.text('我要看活動'), findsOneWidget);
    expect(find.text('正在查找導航預覽…'), findsOneWidget);
    pending.complete(result('incomplete'));
    await tester.pumpAndSettle();
    expect(find.text('目前無法直接開啟這個頁面，所需資料尚未準備好。'), findsOneWidget);
    expect(find.textContaining('ActivityList'), findsNothing);
  });
  testWidgets(
    'welcome and suggestions give way to messages; keyboard keeps the latest visible',
    (tester) async {
      final client = FakeClient(
        (query) async => result(
          'incomplete',
          reason: List.filled(24, '來源資料與導航限制').join('\n'),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: AssistantView(client: client),
        ),
      );
      expect(find.text('嗨！我是市政 AI 助理'), findsOneWidget);
      expect(find.text('我要看活動訊息'), findsOneWidget);
      expect(find.text('你好！我可以協助查找市政功能，並顯示來源可查的導航預覽。'), findsNothing);
      await tester.enterText(find.byKey(const Key('assistant-input')), '第一個問題');
      await tester.tap(find.byKey(const Key('assistant-send')));
      await tester.pumpAndSettle();
      expect(find.text('嗨！我是市政 AI 助理'), findsNothing);
      expect(find.text('我要看活動訊息'), findsNothing);
      void expectLatestHeaderVisible() {
        final top = tester
            .getTopLeft(find.text('目前無法直接開啟這個頁面，所需資料尚未準備好。').last)
            .dy;
        final viewport = find.byKey(const Key('assistant-messages'));
        expect(top, greaterThanOrEqualTo(tester.getTopLeft(viewport).dy));
        expect(top, lessThan(tester.getBottomLeft(viewport).dy));
      }

      expectLatestHeaderVisible();
      await tester.enterText(find.byKey(const Key('assistant-input')), '第二個問題');
      await tester.tap(find.byKey(const Key('assistant-send')));
      await tester.pumpAndSettle();
      expectLatestHeaderVisible();
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectLatestHeaderVisible();
      expect(
        tester.getBottomLeft(find.byKey(const Key('assistant-input'))).dy,
        lessThanOrEqualTo(
          (tester.view.physicalSize.height - 900) /
              tester.view.devicePixelRatio,
        ),
      );
    },
  );

  testWidgets('activity navigation waits for the real runtime data', (
    tester,
  ) async {
    var navigated = false;
    final answer = NavigationResult(
      {
        'intent': 'browse_or_navigate',
        'action_allowed': false,
        'decision': 'matched',
        'feature_id': 'activity_information',
        'source': 'name_or_alias',
      },
      {'status': 'incomplete', 'feature_id': 'activity_information'},
      navigationEligible: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AssistantView(
          client: FakeClient((_) async => answer),
          onNavigate: (_) => navigated = true,
          destinationAvailable: (_) => false,
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('assistant-input')), '我要看活動訊息');
    await tester.tap(find.byKey(const Key('assistant-send')));
    await tester.pumpAndSettle();
    expect(navigated, isFalse);
    expect(find.text('活動資料尚未準備好，請稍後再試。'), findsOneWidget);
  });

  testWidgets('unsupported, rejected action and unavailable model', (
    tester,
  ) async {
    final answers = [
      result('clarify', reason: '不支援此功能'),
      result('rejected', reason: '不可執行操作'),
    ];
    final client = FakeClient((q) async {
      if (q == 'model') throw const NavigationException('本機模型無法使用');
      return answers.removeAt(0);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: AssistantView(client: client),
      ),
    );
    for (final pair in [
      ('unknown', '我無法確認你要找的頁面，請換個方式描述。'),
      ('action', '抱歉，我無法代替你執行付款、購買或其他服務操作。'),
      ('model', '本機模型無法使用'),
    ]) {
      await tester.enterText(find.byKey(const Key('assistant-input')), pair.$1);
      await tester.tap(find.byKey(const Key('assistant-send')));
      await tester.pumpAndSettle();
      expect(find.text(pair.$2), findsOneWidget);
    }
  });
}
