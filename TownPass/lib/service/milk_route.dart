import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Only a public shop is eligible to be passed to the family outing planner.
/// School/home points are held separately and never form part of this value.
class MilkRouteStop {
  const MilkRouteStop({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String name, address;
  final double latitude, longitude;
  LatLng get point => LatLng(latitude, longitude);
  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
  };

  static MilkRouteStop? fromSearch(dynamic item) {
    if (item is! Map) return null;
    final name = item['name'];
    final lat = item['latitude'], lon = item['longitude'];
    if (name is! String ||
        name.trim().isEmpty ||
        lat is! num ||
        lon is! num ||
        !MilkRoute.validPoint(LatLng(lat.toDouble(), lon.toDouble())) ||
        chain(name) == null) {
      return null;
    }
    return MilkRouteStop(
      name: name.trim(),
      address: item['address'] is String ? item['address'] as String : '',
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
    );
  }

  static String? chain(String name) {
    final upper = name.toUpperCase();
    if (upper.contains('7-ELEVEN') ||
        upper.contains('7-11') ||
        upper.contains('統一超商')) {
      return '7-ELEVEN';
    }
    if (name.contains('全家') || upper.contains('FAMILYMART')) return '全家';
    if (RegExp(r'(^|[^A-Z])OK([^A-Z]|$)').hasMatch(upper)) return 'OK';
    if (name.contains('全聯')) return '全聯';
    if (name.contains('美廉社')) return '美廉社';
    if (name.contains('樂家康')) return '樂家康';
    if (name.contains('萊爾富') || upper.contains('HILIFE')) return '萊爾富';
    return null;
  }
}

class MilkRouteCandidate {
  const MilkRouteCandidate(this.stop, this.extraMetres);
  final MilkRouteStop stop;

  /// Additional straight-line distance, not road distance or travel time.
  final double extraMetres;
}

class MilkRoute {
  const MilkRoute({required this.school, required this.home});
  final LatLng school, home;

  static bool validPoint(LatLng point) =>
      point.latitude.isFinite &&
      point.longitude.isFinite &&
      point.latitude.abs() <= 90 &&
      point.longitude.abs() <= 180;

  static double metres(LatLng a, LatLng b) {
    const radius = 6371000.0;
    const radians = math.pi / 180;
    final dLat = (b.latitude - a.latitude) * radians;
    final dLon = (b.longitude - a.longitude) * radians;
    final sinLat = math.sin(dLat / 2), sinLon = math.sin(dLon / 2);
    final h =
        sinLat * sinLat +
        math.cos(a.latitude * radians) *
            math.cos(b.latitude * radians) *
            sinLon *
            sinLon;
    return radius * 2 * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }

  double get directMetres => metres(school, home);
  String? get validationError {
    if (!validPoint(school) || !validPoint(home)) return '請選擇有效的地圖位置。';
    if (directMetres < 80) return '學校和回家位置太接近，請重新選點（至少相隔 80 公尺）。';
    if (directMetres > 30000) return '請選擇 30 公里內的放學行程，再找附近門市。';
    return null;
  }

  /// Three public store searches cover the beginning, middle and end of the
  /// selected corridor. They run only after explicit user confirmation.
  List<LatLng> get searchCenters => [
    for (final t in [0.15, 0.5, 0.85])
      LatLng(
        school.latitude + (home.latitude - school.latitude) * t,
        school.longitude + (home.longitude - school.longitude) * t,
      ),
  ];

  List<MilkRouteCandidate> rank(Iterable<MilkRouteStop> stops) {
    if (validationError != null) return [];
    final allowance = math.max(600.0, math.min(1500.0, directMetres * 0.4));
    final unique = <String, MilkRouteCandidate>{};
    for (final stop in stops) {
      if (!validPoint(stop.point)) continue;
      final extra = math.max(
        0.0,
        metres(school, stop.point) + metres(stop.point, home) - directMetres,
      );
      if (extra > allowance) continue;
      final key =
          '${stop.name}-${stop.latitude.toStringAsFixed(5)}-${stop.longitude.toStringAsFixed(5)}';
      unique[key] = MilkRouteCandidate(stop, extra);
    }
    return unique.values.toList()..sort((a, b) {
      final score = a.extraMetres.compareTo(b.extraMetres);
      return score != 0 ? score : a.stop.name.compareTo(b.stop.name);
    });
  }

  Map<String, dynamic> toJson() => {
    'school': {'latitude': school.latitude, 'longitude': school.longitude},
    'home': {'latitude': home.latitude, 'longitude': home.longitude},
  };

  static MilkRoute? fromJson(dynamic value) {
    try {
      if (value is! Map) return null;
      LatLng read(String key) {
        final point = value[key] as Map;
        return LatLng(
          (point['latitude'] as num).toDouble(),
          (point['longitude'] as num).toDouble(),
        );
      }

      final route = MilkRoute(school: read('school'), home: read('home'));
      return route.validationError == null ? route : null;
    } catch (_) {
      return null;
    }
  }
}

/// Explicitly saved only on this device; not included in family synchronization.
class MilkRouteStore {
  static const key = 'milk_local_route_v1';
  static Future<MilkRoute?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return null;
    try {
      return MilkRoute.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(MilkRoute route) async {
    if (route.validationError != null) {
      throw FormatException(route.validationError!);
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, jsonEncode(route.toJson()))) {
      throw StateError('無法儲存放學行程，請重試。');
    }
  }

  static Future<void> clear() async {
    if (!await (await SharedPreferences.getInstance()).remove(key)) {
      throw StateError('無法清除放學行程，請重試。');
    }
  }
}
