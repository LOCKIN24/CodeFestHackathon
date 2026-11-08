import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/service/milk_route.dart';

const school = LatLng(25.0375, 121.55);
const home = LatLng(25.0375, 121.57);
const route = MilkRoute(school: school, home: home);
MilkRouteStop shop(String name, double lat, double lon) =>
    MilkRouteStop(name: name, address: '公開門市地址', latitude: lat, longitude: lon);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('corridor sorts less extra distance first and excludes far detours', () {
    final ranked = route.rank([
      shop('全家 偏離門市', 25.041, 121.56),
      shop('全家 直線門市', 25.0375, 121.56),
      shop('全家 太遠門市', 25.15, 121.56),
      shop('全家 直線門市', 25.0375, 121.56),
    ]);
    expect(ranked.map((s) => s.stop.name), ['全家 直線門市', '全家 偏離門市']);
    expect(ranked.first.extraMetres, closeTo(0, 1));
    expect(ranked.last.extraMetres, greaterThan(100));
    expect(route.directMetres, inInclusiveRange(1900, 2100));
  });

  test('invalid, nearly identical and far apart endpoints are rejected', () {
    expect(
      const MilkRoute(school: school, home: school).validationError,
      isNotNull,
    );
    expect(
      const MilkRoute(school: school, home: LatLng(100, 0)).validationError,
      isNotNull,
    );
    expect(
      const MilkRoute(
        school: school,
        home: LatLng(double.nan, 0),
      ).validationError,
      isNotNull,
    );
    expect(
      const MilkRoute(school: school, home: LatLng(24, 121)).validationError,
      isNotNull,
    );
    expect(
      const MilkRoute(school: school, home: school).rank([shop('全家', 25, 121)]),
      isEmpty,
    );
  });

  test('three search samples stay between the selected endpoints', () {
    expect(route.searchCenters, hasLength(3));
    for (final center in route.searchCenters) {
      expect(center.latitude, 25.0375);
      expect(center.longitude, greaterThan(school.longitude));
      expect(center.longitude, lessThan(home.longitude));
    }
  });

  test('search parsing ignores unrelated chains and malformed coordinates', () {
    Map<String, dynamic> payload(String name) => {
      'name': name,
      'latitude': 25.0375,
      'longitude': 121.56,
      'address': '公開地址',
    };
    expect(MilkRouteStop.fromSearch(payload('全家 測試門市')), isNotNull);
    expect(MilkRouteStop.fromSearch(payload('BOOK STORE')), isNull);
    expect(MilkRouteStop.fromSearch(payload('OK便利商店')), isNotNull);
    expect(
      MilkRouteStop.fromSearch({...payload('全家'), 'latitude': double.infinity}),
      isNull,
    );
    expect(
      MilkRouteStop.fromSearch({...payload('全家'), 'latitude': '25'}),
      isNull,
    );
    expect(MilkRouteStop.fromSearch(null), isNull);
  });

  test('explicit save and clear preserve unrelated family data', () async {
    SharedPreferences.setMockInitialValues({
      'milk_family_v2': 'private fixture',
    });
    expect(await MilkRouteStore.load(), isNull);
    await MilkRouteStore.save(route);
    final restored = (await MilkRouteStore.load())!;
    expect(restored.school, school);
    expect(restored.home, home);
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString(MilkRouteStore.key)!), route.toJson());
    await MilkRouteStore.clear();
    expect(await MilkRouteStore.load(), isNull);
    expect(prefs.getString('milk_family_v2'), 'private fixture');
  });

  test(
    'damaged local data is ignored and invalid routes are never saved',
    () async {
      SharedPreferences.setMockInitialValues({MilkRouteStore.key: '{broken'});
      expect(await MilkRouteStore.load(), isNull);
      expect(MilkRoute.fromJson({'school': {}, 'home': {}}), isNull);
      await expectLater(
        MilkRouteStore.save(const MilkRoute(school: school, home: school)),
        throwsFormatException,
      );
    },
  );

  test(
    'shareable stop contains only the public store and no route endpoints',
    () {
      final stop = shop('全家', 25.0375, 121.56);
      expect(
        stop.toJson().keys,
        unorderedEquals(['name', 'address', 'latitude', 'longitude']),
      );
      expect(stop.toJson(), isNot(contains('school')));
      expect(stop.toJson(), isNot(contains('home')));
    },
  );
}
