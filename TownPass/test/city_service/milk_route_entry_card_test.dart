import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/page/city_service/milk_route_entry_card.dart';
import 'package:town_pass/page/city_service/milk_route_view.dart';
import 'package:town_pass/util/tp_colors.dart';

void main() {
  testWidgets(
    'route entry uses outing-style surface and comfortable action at large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: SingleChildScrollView(child: MilkRouteEntryCard()),
            ),
          ),
        ),
      );
      expect(find.text('放學順路領'), findsOneWidget);
      final action = find.widgetWithText(FilledButton, '找順路門市');
      expect(tester.getSize(action).height, greaterThanOrEqualTo(56));
      final card = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(MilkRouteEntryCard),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((card.decoration as BoxDecoration).color, TPColors.white);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'route entry opens existing route picker without searching or changing saved points',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: MilkRouteEntryCard()),
          ),
        ),
      );
      await tester.tap(find.text('找順路門市'));
      await tester.pumpAndSettle();
      expect(find.byType(MilkRouteView), findsOneWidget);
      expect(find.byKey(const Key('milk-route-school')), findsOneWidget);
      expect(find.byKey(const Key('milk-route-home')), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
