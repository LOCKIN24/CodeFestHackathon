import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:town_pass/page/city_service/milk_outing_card.dart';
import 'package:town_pass/service/milk_outing.dart';
import 'package:town_pass/service/milk_route.dart';

const _store = MilkRouteStop(
  name: '全家 測試門市',
  address: '測試公開地址',
  latitude: 25.03,
  longitude: 121.56,
);

void main() {
  testWidgets(
    'shared plan is readable offline with mutation disabled at large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: SingleChildScrollView(
                child: MilkOutingCard(
                  profile: {
                    'id': 'a' * 32,
                    'records': [],
                    'outing': {
                      'week': milkOutingWeek(now),
                      'status': 'planned',
                      'revision': 2,
                      'plannedAt': now.toUtc().toIso8601String(),
                      'store': _store.toJson(),
                    },
                  },
                  childMode: true,
                  enabled: false,
                  onBusyChanged: (_) {},
                  onChanged: (_) async {},
                  onRefresh: () async {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('約好了，一起去領！'), findsOneWidget);
      expect(find.text(_store.name), findsOneWidget);
      expect(find.textContaining('台北時間'), findsOneWidget);
      expect(find.textContaining('行程暫時無法更改'), findsOneWidget);
      final cancel = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '取消行程'),
      );
      expect(cancel.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a recorded week closes the mission and removes request action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MilkOutingCard(
            profile: {
              'id': 'a' * 32,
              'records': [
                {'week': milkOutingWeek(DateTime.now())},
              ],
            },
            childMode: true,
            enabled: true,
            onBusyChanged: (_) {},
            onChanged: (_) async {},
            onRefresh: () async {},
          ),
        ),
      ),
    );
    expect(find.text('本週領取已完成'), findsOneWidget);
    expect(find.text('陪我去領'), findsNothing);
  });

  testWidgets('parent previews chosen public store then returns a UTC plan', (
    tester,
  ) async {
    MilkOutingPlan? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.push<MilkOutingPlan>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MilkOutingPlanView(chooseNearby: () async => _store),
                  ),
                );
              },
              child: const Text('開始'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開始'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('確認並分享行程'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('確認並分享行程'));
    await tester.pump();
    expect(find.text('請先選擇一起去的門市。'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('從附近門市選擇'),
      -250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('從附近門市選擇'));
    await tester.pumpAndSettle();
    expect(find.text(_store.name), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('確認並分享行程'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('確認並分享行程'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.store.toJson(), _store.toJson());
    expect(result!.plannedAt.isUtc, isTrue);
    expect(result!.plannedAt.isAfter(DateTime.now()), isTrue);
    expect(milkOutingWeek(result!.plannedAt), milkOutingWeek(DateTime.now()));
  });
}
