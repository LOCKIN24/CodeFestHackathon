import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:town_pass/page/ai_assistant/assistant_sheet.dart';

Widget harness({bool reduced = false}) => MaterialApp(
  theme: ThemeData(splashFactory: NoSplash.splashFactory),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: child!,
  ),
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => showAssistantSheet(context),
        child: const Text('open'),
      ),
    ),
  ),
);

void main() {
  testWidgets('drag follows finger, expands, preserves input, and dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('preview-notice')), findsOneWidget);
    expect(tester.widget<AppBar>(find.byType(AppBar)).primary, isFalse);
    expect(find.byKey(const Key('assistant-expand')), findsNothing);
    expect(find.byKey(const Key('assistant-close')), findsNothing);
    final sheet = find.byKey(const Key('assistant-sheet'));
    final initial = tester.getSize(sheet).height;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('assistant-sheet-handle'))),
    );
    await gesture.moveBy(const Offset(0, -25));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -90));
    await tester.pump();
    expect(tester.getSize(sheet).height, greaterThan(initial));
    await gesture.up();
    await tester.pumpAndSettle();
    final expanded = tester.getSize(sheet).height;
    expect(expanded, greaterThan(initial));
    await tester.enterText(find.byKey(const Key('assistant-input')), 'unsent');
    await tester.drag(
      find.byKey(const Key('assistant-sheet-handle')),
      const Offset(0, 160),
    );
    await tester.pumpAndSettle();
    expect(find.text('unsent'), findsOneWidget);
    expect(tester.getSize(sheet).height, lessThan(expanded));
    await tester.drag(
      find.byKey(const Key('assistant-sheet-handle')),
      const Offset(0, 250),
    );
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('keyboard inset fits and system back dismisses', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-input')));
    await tester.showKeyboard(find.byKey(const Key('assistant-input')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getBottomLeft(find.byKey(const Key('assistant-input'))).dy,
      lessThanOrEqualTo(
        (tester.view.physicalSize.height - 900) / tester.view.devicePixelRatio,
      ),
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant-sheet')), findsNothing);
  });

  testWidgets(
    'accessible handle can dismiss and reduced motion settles immediately',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(harness(reduced: true));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('assistant-sheet')), findsOneWidget);
      final handle = find.bySemanticsLabel('關閉 AI 助理').last;
      final node = tester.getSemantics(handle);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      // The test view owns the semantics nodes, not the root pipeline owner.
      // ignore: deprecated_member_use
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.tap,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assistant-sheet')), findsNothing);
      semantics.dispose();
    },
  );
}
