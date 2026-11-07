import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:town_pass/page/main/assistant_bottom_navigation.dart';

class NavigationHarness extends StatefulWidget {
  const NavigationHarness({super.key});
  @override
  State<NavigationHarness> createState() => _NavigationHarnessState();
}

class _NavigationHarnessState extends State<NavigationHarness> {
  int index = 1;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Text('selected:$index'),
    bottomNavigationBar: AssistantBottomNavigation(
      currentIndex: index,
      onSelect: (value) => setState(() => index = value),
      openAssistant: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              Scaffold(appBar: AppBar(), body: const Text('assistant screen')),
        ),
      ),
    ),
  );
}

Future<void> settleAnimations(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 160));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets(
    'four tabs keep their original indices and assistant preserves selection',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: const NavigationHarness(),
        ),
      );
      for (final entry in [(0, '服務'), (2, '優惠'), (1, '首頁'), (3, '帳務')]) {
        expect(find.text(entry.$2), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('navigation-tab-${entry.$1}')));
        await tester.pump();
        expect(find.text('selected:${entry.$1}'), findsOneWidget);
      }
      final positions = [0, 2, 1, 3]
          .map(
            (i) =>
                tester.getCenter(find.byKey(ValueKey('navigation-tab-$i'))).dx,
          )
          .toList();
      final center = tester
          .getCenter(find.byKey(const Key('assistant-launcher')))
          .dx;
      expect(positions[0], lessThan(positions[1]));
      expect(positions[1], lessThan(center));
      expect(center, lessThan(positions[2]));
      expect(positions[2], lessThan(positions[3]));
      expect(
        center,
        closeTo(tester.getSize(find.byType(Scaffold).first).width / 2, 0.1),
      );
      await tester.tap(find.byKey(const Key('assistant-launcher')));
      await settleAnimations(tester);
      expect(find.text('assistant screen'), findsOneWidget);
      await tester.pageBack();
      await settleAnimations(tester);
      expect(find.text('selected:3'), findsOneWidget);
    },
  );

  testWidgets('long press produces one haptic and opens once', (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: const NavigationHarness(),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('assistant-launcher'))),
    );
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, .9);
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      calls
          .where(
            (c) =>
                c.method == 'HapticFeedback.vibrate' &&
                c.arguments == 'HapticFeedbackType.mediumImpact',
          )
          .length,
      1,
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('assistant screen'),
      findsOneWidget,
      reason: 'opens before pointer release',
    );
    await gesture.up();
    await settleAnimations(tester);
    expect(find.text('assistant screen'), findsOneWidget);
    await tester.pageBack();
    await settleAnimations(tester);
    expect(find.text('selected:1'), findsOneWidget);
  });

  testWidgets('upward gesture opens once, while a tab swipe does not', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: const NavigationHarness(),
      ),
    );
    await tester.drag(
      find.byKey(const ValueKey('navigation-tab-0')),
      const Offset(0, -45),
    );
    await settleAnimations(tester);
    expect(find.text('assistant screen'), findsNothing);
    await tester.drag(
      find.byKey(const Key('assistant-launcher')),
      const Offset(0, -55),
    );
    await settleAnimations(tester);
    expect(find.text('assistant screen'), findsOneWidget);
    await tester.pageBack();
    await settleAnimations(tester);
    expect(find.text('selected:1'), findsOneWidget);
  });

  testWidgets('short hold opens on release and a downward drag cancels', (
    tester,
  ) async {
    final completion = Completer<void>();
    var count = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AssistantBottomNavigation(
            currentIndex: 1,
            onSelect: (_) {},
            openAssistant: () {
              count++;
              return completion.future;
            },
          ),
        ),
      ),
    );
    final launcher = find.byKey(const Key('assistant-launcher'));
    final cancel = await tester.startGesture(tester.getCenter(launcher));
    await cancel.moveBy(const Offset(0, 35));
    await cancel.moveBy(const Offset(0, 35));
    await cancel.up();
    await tester.pump(const Duration(milliseconds: 600));
    expect(count, 0);
    final tap = await tester.startGesture(tester.getCenter(launcher));
    await tester.pump(const Duration(milliseconds: 250));
    expect(count, 0);
    await tap.up();
    await tester.pump();
    expect(count, 1);
    completion.complete();
  });

  testWidgets('mascot floats while idle and stops for reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AssistantBottomNavigation(
            currentIndex: 1,
            onSelect: (_) {},
            openAssistant: () async {},
          ),
        ),
      ),
    );
    double position() => tester
        .widget<Transform>(find.byKey(const Key('mascot-bob')))
        .transform
        .storage[13];
    final start = position();
    await tester.pump(const Duration(milliseconds: 800));
    expect(position(), isNot(start));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            bottomNavigationBar: AssistantBottomNavigation(
              currentIndex: 1,
              onSelect: (_) {},
              openAssistant: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final still = position();
    await tester.pump(const Duration(milliseconds: 800));
    expect(position(), still);
  });

  testWidgets('rapid taps cannot open two assistant routes', (tester) async {
    final completion = Completer<void>();
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          bottomNavigationBar: AssistantBottomNavigation(
            currentIndex: 1,
            onSelect: (_) {},
            openAssistant: () {
              opens++;
              return completion.future;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('assistant-launcher')));
    await tester.tap(find.byKey(const Key('assistant-launcher')));
    await tester.pump(const Duration(milliseconds: 160));
    expect(opens, 1);
    completion.complete();
  });

  testWidgets(
    'fits narrow and wide screens with bottom insets and reduced motion',
    (tester) async {
      for (final width in [320.0, 430.0, 600.0]) {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 700),
                padding: const EdgeInsets.only(bottom: 34),
                disableAnimations: true,
                textScaler: const TextScaler.linear(1.5),
              ),
              child: const NavigationHarness(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          tester.getCenter(find.byKey(const Key('assistant-launcher'))).dx,
          closeTo(width / 2, 0.1),
        );
        expect(
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
          Duration.zero,
        );
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );
}
