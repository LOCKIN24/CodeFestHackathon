import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:town_pass/page/city_service/milk_passport_view.dart';
import 'package:town_pass/service/milk_passport.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real local WKWebView opens, browses, replays, pauses and releases',
    (tester) async {
      InAppWebViewController? controller;
      final records = <Map<String, dynamic>>[
        {'week': '2026-10-26', 'product': '豆漿', 'date': '2026/10/27 16:00'},
        {'week': '2026-10-12', 'product': '鮮奶', 'date': '2026/10/13 16:00'},
      ];
      final passport = MilkPassport.fromRecords(records);
      await tester.pumpWidget(
        MaterialApp(
          home: MilkPassportView(
            passport: passport,
            onRendererCreated: (value) => controller = value,
          ),
        ),
      );
      Future<dynamic> js(String source) async =>
          controller!.evaluateJavascript(source: source);
      Future<Map<String, dynamic>> state() async => jsonDecode(
        await js('JSON.stringify(window.milkPassportHost.getState())')
            as String,
      ) as Map<String, dynamic>;
      Future<void> until(
        Future<bool> Function() predicate, {
        int seconds = 25,
      }) async {
        final end = DateTime.now().add(Duration(seconds: seconds));
        while (DateTime.now().isBefore(end)) {
          await tester.pump(const Duration(milliseconds: 200));
          try {
            if (await predicate()) return;
          } catch (_) {}
        }
        fail('Native passport state did not arrive before timeout');
      }

      Future<void> shot(String name) async {
        final bytes = await binding.takeScreenshot(name);
        await File('${Directory.systemTemp.path}/$name.png')
            .writeAsBytes(bytes);
      }

      await until(
        () async => controller != null && (await state())['ready'] == true,
      );
      expect((await state())['renderMode'], 'webgl');
      expect((await state())['stamps'], passport.stamps);
      final localUrl = await controller!.getUrl();
      expect(localUrl!.scheme, 'file');
      await shot('passport-native-cover');
      debugPrint('PASSPORT_NATIVE local WebGL ready');
      await js("document.getElementById('open-passport').click()");
      await until(
        () async =>
            await js(
              "document.getElementById('passport-browser').open && document.getElementById('passport-browser').dataset.opening === 'false'",
            ) ==
            true,
      );
      await shot('passport-native-open');
      await js("document.getElementById('next-spread').click()");
      await until(
        () async =>
            await js(
              "document.getElementById('passport-browser').dataset.spread === '1' && document.getElementById('passport-browser').dataset.turning === 'false'",
            ) ==
            true,
      );
      await js("document.getElementById('previous-spread').click()");
      await until(
        () async =>
            await js(
              "document.getElementById('passport-browser').dataset.spread === '0' && document.getElementById('passport-browser').dataset.turning === 'false'",
            ) ==
            true,
      );
      await js("document.querySelectorAll('.stamp-hotspot')[1].click()");
      await until(
        () async =>
            await js("document.getElementById('stamp-details').open") == true,
      );
      expect(
        await js("document.getElementById('stamp-drink').textContent"),
        '豆漿',
      );
      expect(
        await js("document.getElementById('stamp-date').textContent"),
        contains('2026 年 10 月 27 日'),
      );
      await shot('passport-native-details');
      debugPrint('PASSPORT_NATIVE browsing verified');
      await js(
        "document.getElementById('return-to-passport').click(); document.getElementById('close-passport').click(); document.getElementById('replay').click()",
      );
      await until(() async => (await state())['busy'] == true);
      final lifecycle =
          tester.state(find.byType(MilkPassportView)) as WidgetsBindingObserver;
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      debugPrint('PASSPORT_NATIVE paused renderer');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect((await state())['suspended'], isTrue);
      final frames = (await state())['frames'];
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect((await state())['frames'], frames);
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      debugPrint('PASSPORT_NATIVE resumed renderer');
      await until(() async => (await state())['busy'] == false, seconds: 20);
      expect((await state())['stamps'], passport.stamps);
      await js('window.milkPassportHost.dispose()');
      expect((await state())['disposed'], isTrue);
      expect((await state())['stamps'], isEmpty);
      expect(records.length, 2);
      debugPrint('PASSPORT_NATIVE replay and disposal verified');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
