import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/page/city_service/milk_route_view.dart';
import 'package:town_pass/service/milk_route.dart';
import 'package:town_pass/service/milk_family_store.dart';

const channel = MethodChannel('townpass/store_search');
const route = MilkRoute(
  school: LatLng(25.0375, 121.55),
  home: LatLng(25.0375, 121.57),
);
Map<String, dynamic> shop(String name) => {
  'name': name,
  'address': '測試公開門市',
  'latitude': 25.0375,
  'longitude': 121.56,
};
Future<void> show(
  WidgetTester tester, {
  bool saved = true,
  bool select = false,
}) async {
  SharedPreferences.setMockInitialValues({
    if (saved) MilkRouteStore.key: jsonEncode(route.toJson()),
    MilkFamilyStore.key: jsonEncode([
      {'id': 'a', 'number': '1', 'name': '學生', 'school': '信義國小'},
    ]),
    MilkFamilyStore.selectedKey: 'a',
  });
  await tester.binding.setSurfaceSize(const Size(440, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: MilkRouteView(selectMode: select)));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  // Card grouping makes the list taller. Use the side gutter so the map does
  // not consume a scroll gesture, and settle before checking the hit bounds.
  final height = tester.getSize(find.byType(Scaffold).last).height;
  for (var attempt = 0; attempt < 16; attempt++) {
    await tester.pumpAndSettle();
    if (target.evaluate().isNotEmpty) {
      final bounds = tester.getRect(target);
      if (bounds.top >= 110 && bounds.bottom < height - 30) return;
      await tester.dragFrom(
        Offset(8, height - 160),
        Offset(0, bounds.top < 110 ? 250 : -250),
      );
    } else {
      await tester.dragFrom(Offset(8, height - 160), const Offset(0, -250));
    }
  }
  fail('Route action did not become visible after scrolling');
}

Future<void> search(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('milk-route-search')));
  await tester.tap(find.byKey(const Key('milk-route-search')));
  await tester.pumpAndSettle();
}

Future<void> close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('townpass/place_search'),
          (_) async => [
            {
              'name': '信義國小',
              'latitude': route.school.latitude,
              'longitude': route.school.longitude,
            },
          ],
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => []);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('townpass/place_search'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('restores local route and automatically searches', (
    tester,
  ) async {
    final queries = <Map>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          queries.add(call.arguments as Map);
          return [shop('全家 順路門市')];
        });
    await show(tester);
    expect(queries, hasLength(3));
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(queries, hasLength(3));
    await tester.scrollUntilVisible(
      find.text('全家 順路門市'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('全家 順路門市'), findsOneWidget);
    expect(find.textContaining('直線增加約'), findsOneWidget);
    await reveal(tester, find.text('選這間順路領'));
    await tester.tap(find.text('選這間順路領'));
    await tester.pumpAndSettle();
    expect(find.text('已選為順路門市'), findsOneWidget);
    expect(
      tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines
          .single
          .points,
      hasLength(3),
    );
    await close(tester);
  });

  testWidgets('clear removes saved home but keeps the school', (tester) async {
    await show(tester);
    await reveal(tester, find.text('清除行程'));
    await tester.tap(find.text('清除行程'));
    await tester.pumpAndSettle();
    expect(await MilkRouteStore.load(), isNull);
    await tester.ensureVisible(find.text('學校：信義國小'));
    expect(find.text('學校：信義國小'), findsOneWidget);
    await close(tester);
  });

  testWidgets(
    'empty and failed searches give useful recovery instead of invented shops',
    (tester) async {
      await show(tester);
      await search(tester);
      await tester.scrollUntilVisible(
        find.textContaining('找不到合適的門市'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('找不到合適的門市'), findsOneWidget);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(code: 'offline'),
          );
      await search(tester);
      await tester.scrollUntilVisible(
        find.text('重新搜尋'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('無法搜尋門市'), findsOneWidget);
      expect(find.text('重新搜尋'), findsOneWidget);
      await close(tester);
    },
  );

  testWidgets('clearing invalidates in-flight results', (tester) async {
    final response = Completer<List<dynamic>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) => response.future);
    await show(tester);
    await reveal(tester, find.text('清除行程'));
    await tester.tap(find.text('清除行程'));
    await tester.pump();
    response.complete([shop('全家 過時門市')]);
    await tester.pumpAndSettle();
    expect(find.text('全家 過時門市'), findsNothing);
    await close(tester);
  });

  testWidgets('store selection returns only public shop information', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      MilkRouteStore.key: jsonEncode(route.toJson()),
      MilkFamilyStore.key: jsonEncode([
        {'id': 'a', 'number': '1', 'name': '學生', 'school': '信義國小'},
      ]),
      MilkFamilyStore.selectedKey: 'a',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => [shop('全家 選擇門市')]);
    MilkRouteStop? selected;
    await tester.binding.setSurfaceSize(const Size(440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await Navigator.push<MilkRouteStop>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MilkRouteView(selectMode: true),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await search(tester);
    await reveal(tester, find.text('選這間，一起去'));
    await tester.tap(find.text('選這間，一起去'));
    await tester.pumpAndSettle();
    expect(selected?.name, '全家 選擇門市');
    expect(
      selected?.toJson().keys,
      unorderedEquals(['name', 'address', 'latitude', 'longitude']),
    );
    await close(tester);
  });

  testWidgets('narrow enlarged text layout remains usable', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(320, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: const MilkRouteView(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Drag the list's side gutter: a gesture centered over FlutterMap pans the
    // map, rather than scrolling the parent list at this enlarged text size.
    for (var i = 0; i < 6 && find.text('清除行程').evaluate().isEmpty; i++) {
      await tester.dragFrom(const Offset(8, 650), const Offset(0, -450));
      await tester.pumpAndSettle();
    }
    expect(find.text('清除行程'), findsOneWidget);
    await tester.ensureVisible(find.text('清除行程'));
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
