import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:town_pass/page/city_service/milk_service_view.dart';

const _storeChannel = MethodChannel('townpass/store_search');
const _point = LatLng(25.0375, 121.5645);

Position _position() => Position(
  latitude: _point.latitude,
  longitude: _point.longitude,
  timestamp: DateTime.utc(2026, 11, 8),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

Map<String, Object> _store(
  String name, {
  double latitude = 25.0385,
  double longitude = 121.5645,
}) => {
  'name': name,
  'address': '測試地址',
  'latitude': latitude,
  'longitude': longitude,
};

class _Location extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.denied;
  LocationPermission requestedPermission = LocationPermission.denied;
  int permissionRequests = 0;
  int positionRequests = 0;
  Future<Position> Function() locate = () async => _position();

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    permission = requestedPermission;
    return permission;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    positionRequests++;
    return locate();
  }
}

Iterable<Marker> _positionMarkers(WidgetTester tester) => tester
    .widgetList<MarkerLayer>(find.byType(MarkerLayer))
    .expand((layer) => layer.markers)
    .where(
      (marker) =>
          marker.key == const Key('milk-current-location') ||
          marker.child.key == const Key('milk-current-location'),
    );

Future<void> _show(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(440, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MaterialApp(home: MilkStoresView()));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  late GeolocatorPlatform previous;
  late _Location location;

  setUp(() {
    previous = GeolocatorPlatform.instance;
    location = _Location();
    GeolocatorPlatform.instance = location;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storeChannel, (_) async => []);
  });

  tearDown(() {
    GeolocatorPlatform.instance = previous;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storeChannel, null);
  });

  testWidgets('fallback and denied permission never invent a device location', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _storeChannel,
          (_) async => [_store('全家便利商店 測試門市')],
        );
    await _show(tester);
    expect(_positionMarkers(tester), isEmpty);
    expect(location.permissionRequests, 0);
    expect(location.positionRequests, 0);
    expect(find.textContaining('距搜尋中心'), findsOneWidget);

    await tester.tap(find.text('使用目前位置'));
    await tester.pumpAndSettle();
    expect(location.permissionRequests, 1);
    expect(location.positionRequests, 0);
    expect(_positionMarkers(tester), isEmpty);
    await _close(tester);
  });

  testWidgets(
    'an allowed location appears as a separate current-position dot',
    (tester) async {
      location.permission = LocationPermission.whileInUse;
      await _show(tester);
      await tester.pumpAndSettle();
      final marker = _positionMarkers(tester).single;
      expect(marker.point.latitude, _point.latitude);
      expect(marker.point.longitude, _point.longitude);
      expect(find.byKey(const Key('milk-current-location')), findsOneWidget);
      expect(location.permissionRequests, 0);
      expect(location.positionRequests, 1);
      await _close(tester);
    },
  );

  testWidgets(
    'one explicit request waits for permission and ignores double taps',
    (tester) async {
      final fix = Completer<Position>();
      location.requestedPermission = LocationPermission.whileInUse;
      location.locate = () => fix.future;
      await _show(tester);
      await tester.tap(find.text('使用目前位置'));
      await tester.pump();
      expect(location.permissionRequests, 1);
      expect(location.positionRequests, 1);
      expect(_positionMarkers(tester), isEmpty);

      await tester.tap(find.widgetWithIcon(TextButton, Icons.my_location));
      await tester.pump();
      expect(location.permissionRequests, 1);
      expect(location.positionRequests, 1);

      fix.complete(_position());
      await tester.pumpAndSettle();
      expect(_positionMarkers(tester).single.point.latitude, _point.latitude);
      await _close(tester);
    },
  );

  testWidgets('moving the map automatically loads pins for the new area', (
    tester,
  ) async {
    final origins = <Map<dynamic, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storeChannel, (call) async {
          final args = call.arguments as Map;
          origins.add(args);
          return [
            _store(
              '全家便利商店 地圖門市',
              latitude: args['latitude'] as double,
              longitude: args['longitude'] as double,
            ),
          ];
        });
    await _show(tester);
    await tester.drag(find.byType(FlutterMap), const Offset(-180, 0));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(origins.length, greaterThanOrEqualTo(2));
    expect(
      origins.last['longitude'],
      isNot(closeTo(_point.longitude, 0.00001)),
    );
    final markers = tester
        .widgetList<MarkerLayer>(find.byType(MarkerLayer))
        .expand((layer) => layer.markers);
    expect(
      markers.any(
        (marker) =>
            (marker.point.longitude - (origins.last['longitude'] as double))
                .abs() <
            0.00001,
      ),
      isTrue,
    );
    await _close(tester);
  });

  testWidgets('moving invalidates an earlier search before the debounce', (
    tester,
  ) async {
    final old = Completer<List<Map<String, Object>>>();
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storeChannel, (_) {
          calls++;
          return calls == 1
              ? old.future
              : Future.value(<Map<String, Object>>[]);
        });
    await _show(tester);
    await tester.drag(find.byType(FlutterMap), const Offset(-180, 0));
    old.complete([_store('全家便利商店 舊位置')]);
    await tester.pump();
    expect(find.text('全家便利商店 舊位置'), findsNothing);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(calls, 2);
    await _close(tester);
  });

  testWidgets('older search success cannot replace newer map-area results', (
    tester,
  ) async {
    final old = Completer<List<Map<String, Object>>>();
    final origins = <Map<dynamic, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storeChannel, (call) {
          origins.add(call.arguments as Map);
          return origins.length == 1
              ? old.future
              : Future.value([
                  _store('全家便利商店 新搜尋結果', latitude: 25.05, longitude: 121.55),
                ]);
        });
    await _show(tester);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.mapController!.move(const LatLng(25.05, 121.55), 14);
    await tester.pump();
    await tester.tap(find.text('搜尋地圖範圍'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(origins, hasLength(2));
    expect(origins.last['latitude'], closeTo(25.05, 0.000001));
    expect(find.text('全家便利商店 新搜尋結果'), findsOneWidget);

    old.complete([_store('全家便利商店 舊搜尋結果')]);
    await tester.pumpAndSettle();
    expect(find.text('全家便利商店 新搜尋結果'), findsOneWidget);
    expect(find.text('全家便利商店 舊搜尋結果'), findsNothing);
    await _close(tester);
  });

  testWidgets('older search failure cannot hide newer successful results', (
    tester,
  ) async {
    final old = Completer<List<Map<String, Object>>>();
    var requests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storeChannel, (_) {
          requests++;
          return requests == 1
              ? old.future
              : Future.value([_store('全家便利商店 最新結果')]);
        });
    await _show(tester);
    await tester.tap(find.text('搜尋地圖範圍'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('全家便利商店 最新結果'), findsOneWidget);
    old.completeError(PlatformException(code: 'search_failed'));
    await tester.pumpAndSettle();
    expect(find.text('全家便利商店 最新結果'), findsOneWidget);
    expect(find.textContaining('無法載入門市'), findsNothing);
    await _close(tester);
  });

  testWidgets(
    'a stalled search times out and can be retried without stale results',
    (tester) async {
      final stalled = Completer<List<Map<String, Object>>>();
      var requests = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_storeChannel, (_) {
            requests++;
            return requests == 1
                ? stalled.future
                : Future.value([_store('全家便利商店 重試結果')]);
          });
      await _show(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 20));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('無法載入門市'), findsOneWidget);

      await tester.tap(find.text('搜尋地圖範圍'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(requests, 2);
      expect(find.text('全家便利商店 重試結果'), findsOneWidget);
      expect(find.textContaining('無法載入門市'), findsNothing);

      stalled.complete([_store('全家便利商店 逾時舊結果')]);
      await tester.pumpAndSettle();
      expect(find.text('全家便利商店 重試結果'), findsOneWidget);
      expect(find.text('全家便利商店 逾時舊結果'), findsNothing);
      await _close(tester);
    },
  );

  testWidgets(
    'searching a panned map keeps the dot and distance at the device',
    (tester) async {
      location.permission = LocationPermission.whileInUse;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            _storeChannel,
            (_) async => [_store('全家便利商店 近處門市')],
          );
      await _show(tester);
      await tester.pumpAndSettle();
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      map.mapController!.move(const LatLng(25.06, 121.57), 14);
      await tester.pump();
      await tester.tap(find.text('搜尋地圖範圍'));
      await tester.pumpAndSettle();

      final marker = _positionMarkers(tester).single;
      expect(marker.point.latitude, _point.latitude);
      expect(marker.point.longitude, _point.longitude);
      expect(find.textContaining('距目前位置'), findsOneWidget);
      expect(find.textContaining('0.1 公里'), findsOneWidget);
      expect(find.textContaining('距搜尋中心'), findsNothing);
      await _close(tester);
    },
  );

  testWidgets('disabled location services do not request or invent a fix', (
    tester,
  ) async {
    location.enabled = false;
    await _show(tester);
    await tester.tap(find.text('使用目前位置'));
    await tester.pumpAndSettle();
    expect(location.permissionRequests, 0);
    expect(location.positionRequests, 0);
    expect(_positionMarkers(tester), isEmpty);
    await _close(tester);
  });

  testWidgets(
    'a failed fix leaves the map usable without a fake position dot',
    (tester) async {
      location.permission = LocationPermission.whileInUse;
      location.locate = () => Future.error(TimeoutException('no fix'));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            _storeChannel,
            (_) async => [_store('全家便利商店 測試門市')],
          );
      await _show(tester);
      await tester.pumpAndSettle();
      expect(location.positionRequests, 1);
      expect(_positionMarkers(tester), isEmpty);
      expect(find.text('全家便利商店 測試門市'), findsOneWidget);
      expect(find.textContaining('距搜尋中心'), findsOneWidget);
      await _close(tester);
    },
  );
}
