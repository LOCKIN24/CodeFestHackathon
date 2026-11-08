import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/service/milk_family_store.dart';

/// A relay response that lets the screen distinguish an expired link from Wi-Fi
/// interruption without displaying credentials or request details.
class MilkSyncException implements Exception {
  const MilkSyncException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;
  bool get sessionExpired => statusCode == HttpStatus.unauthorized;

  @override
  String toString() => message;
}

/// A temporary local-network demo relay. It never sends card numbers, names,
/// schools, or photos to the relay. This is not a production account system.
class MilkFamilySync {
  static String validateAddress(String input) => _base(input).toString();
  static const _parentUrl = 'milk_sync_parent_url';
  static const _parentToken = 'milk_sync_parent_token';
  static const _sharedIds = 'milk_sync_shared_ids';
  static const _childUrl = 'milk_sync_child_url';
  static const _childToken = 'milk_sync_child_token';

  static Uri _base(String input) {
    final url = Uri.tryParse(input.trim());
    if (url == null ||
        url.scheme != 'http' ||
        url.userInfo.isNotEmpty ||
        url.path.isNotEmpty && url.path != '/' ||
        url.hasQuery ||
        url.hasFragment) {
      throw const FormatException('請輸入區網網址，例如 http://192.168.1.2:8765');
    }
    final ip = InternetAddress.tryParse(url.host);
    if (ip == null || ip.type != InternetAddressType.IPv4) {
      throw const FormatException('請輸入電腦的區網 IPv4 位址。');
    }
    final parts = ip.address.split('.').map(int.parse).toList();
    final isPrivate =
        parts[0] == 10 ||
        parts[0] == 127 ||
        parts[0] == 192 && parts[1] == 168 ||
        parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31;
    if (!isPrivate) throw const FormatException('只允許連線到私人區網。');
    return url;
  }

  static Future<Map<String, dynamic>> _request(
    String base,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final uri = _base(base).replace(path: path);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = body == null
          ? await client.getUrl(uri)
          : await client.postUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        final payload = utf8.encode(jsonEncode(body));
        request.headers.contentType = ContentType.json;
        // The lightweight LAN relay reads Content-Length rather than chunked
        // transfer encoding. Count UTF-8 bytes, including Chinese aliases.
        request.contentLength = payload.length;
        request.add(payload);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 7),
      );
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 7));
      final decoded = jsonDecode(text) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw MilkSyncException(
          statusCode: response.statusCode,
          message: decoded['error']?.toString() ?? '連線失敗',
        );
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  static Future<bool> get isChild async =>
      (await SharedPreferences.getInstance()).getString(_childToken) != null;
  static Future<void> leaveChild() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_childToken);
    await prefs.remove(_childUrl);
    await prefs.remove('milk_child_cache');
    await prefs.remove('milk_child_local_name');
  }

  static Future<String?> get parentUrl async =>
      (await SharedPreferences.getInstance()).getString(_parentUrl);

  static Future<String> invite(MilkChild child, String base, int index) async {
    _base(base);
    final prefs = await SharedPreferences.getInstance();
    final existingUrl = prefs.getString(_parentUrl);
    final existingToken = prefs.getString(_parentToken);
    if (existingUrl != null && existingToken != null && existingUrl != base) {
      throw const FormatException('已有家庭連線，請先重新設定連線，再使用新網址。');
    }
    var token = existingToken;
    if (token == null) {
      final created = await _request(base, '/v1/families', body: {});
      token = created['parentToken'] as String;
      await prefs.setString(_parentUrl, base);
      await prefs.setString(_parentToken, token);
      await prefs.remove(_sharedIds);
    }
    await _request(
      base,
      '/v1/parent/children',
      token: token,
      body: {'childId': child.id, 'alias': '孩子${index + 1}'},
    );
    for (final record in child.records) {
      await _request(
        base,
        '/v1/parent/record',
        token: token,
        body: {'childId': child.id, 'record': _safeRecord(record)},
      );
    }
    final response = await _request(
      base,
      '/v1/parent/invitations',
      token: token,
      body: {'childId': child.id},
    );
    final ids = prefs.getStringList(_sharedIds) ?? [];
    if (!ids.contains(child.id)) {
      ids.add(child.id);
      await prefs.setStringList(_sharedIds, ids);
    }
    return response['code'] as String;
  }

  static Map<String, dynamic> _safeRecord(Map<String, dynamic> record) => {
    'week': record['week'],
    'product': record['product'],
    'date': record['date'],
  };

  static Future<List<MilkChild>?> syncParent(List<MilkChild> children) async {
    final prefs = await SharedPreferences.getInstance();
    final base = prefs.getString(_parentUrl),
        token = prefs.getString(_parentToken);
    final ids = prefs.getStringList(_sharedIds) ?? [];
    if (base == null || token == null || ids.isEmpty) return null;
    for (final child in children.where((c) => ids.contains(c.id))) {
      for (final record in child.records) {
        await _request(
          base,
          '/v1/parent/record',
          token: token,
          body: {'childId': child.id, 'record': _safeRecord(record)},
        );
      }
    }
    final result = await _request(base, '/v1/parent/children', token: token);
    final remote = (result['children'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return children.map((child) {
      final entries = remote.where((r) => r['id'] == child.id);
      if (entries.isEmpty) return child;
      final records = (entries.first['records'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      final localByWeek = {
        for (final record in child.records) record['week']: record,
      };
      final weeks = records.map((r) => r['week']).toSet();
      return MilkChild(
        id: child.id,
        number: child.number,
        name: child.name,
        school: child.school,
        outing: entries.first['outing'] is Map
            ? Map<String, dynamic>.from(entries.first['outing'] as Map)
            : null,
        records: [
          // Store choices and other local metadata never leave this phone.
          // The relay decides the shared product/date if both devices record.
          for (final record in records)
            {...?localByWeek[record['week']], ...record},
          ...child.records.where((r) => !weeks.contains(r['week'])),
        ],
      );
    }).toList();
  }

  static Future<bool> isShared(String childId) async =>
      ((await SharedPreferences.getInstance()).getStringList(_sharedIds) ?? [])
          .contains(childId);

  static Future<void> revoke(String childId) async {
    final prefs = await SharedPreferences.getInstance();
    final base = prefs.getString(_parentUrl),
        token = prefs.getString(_parentToken);
    final ids = prefs.getStringList(_sharedIds) ?? [];
    if (base != null && token != null && ids.contains(childId)) {
      try {
        await _request(
          base,
          '/v1/parent/revoke',
          token: token,
          body: {'childId': childId},
        );
      } on MilkSyncException catch (error) {
        // A restarted relay no longer recognizes the family; its old child
        // links are already invalid. Network failures still require retrying.
        if (!error.sessionExpired) rethrow;
      }
      ids.remove(childId);
      await prefs.setStringList(_sharedIds, ids);
    }
  }

  static Future<bool> clearParent() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = List<String>.from(prefs.getStringList(_sharedIds) ?? []);
    var revoked = true;
    for (final id in ids) {
      try {
        await revoke(id);
      } catch (_) {
        revoked = false;
      }
    }
    await prefs.remove(_parentUrl);
    await prefs.remove(_parentToken);
    await prefs.remove(_sharedIds);
    return revoked;
  }

  static Future<void> join(
    String base,
    String code, {
    String displayName = '',
  }) async {
    final result = await _request(base, '/v1/join', body: {'code': code});
    final prefs = await SharedPreferences.getInstance();
    // Never show the previous child's cached status after changing links. The
    // join response already contains the newly linked child's current profile.
    await prefs.remove('milk_child_cache');
    await prefs.setString(_childUrl, base);
    await prefs.setString(_childToken, result['childToken'] as String);
    await prefs.setString('milk_child_local_name', displayName.trim());
    if (result['child'] is Map) {
      await prefs.setString('milk_child_cache', jsonEncode(result['child']));
    }
  }

  static Future<Map<String, dynamic>> childProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final base = prefs.getString(_childUrl);
    final token = prefs.getString(_childToken);
    if (base == null || token == null) {
      throw const MilkSyncException(
        statusCode: HttpStatus.unauthorized,
        message: '連線已失效，請重新連結。',
      );
    }
    final response = await _request(base, '/v1/child/profile', token: token);
    final profile = Map<String, dynamic>.from(response['child'] as Map);
    if (prefs.getString(_childUrl) == base &&
        prefs.getString(_childToken) == token) {
      await prefs.setString('milk_child_cache', jsonEncode(profile));
    }
    return profile;
  }

  /// Read only the chosen family's public outing, without sharing local school,
  /// home, card or display-name data. A null result means not yet invited.
  static Future<Map<String, dynamic>?> outingProfile({String? childId}) async {
    if (childId == null) return childProfile();
    final prefs = await SharedPreferences.getInstance();
    final base = prefs.getString(_parentUrl),
        token = prefs.getString(_parentToken);
    if (base == null || token == null || !await isShared(childId)) return null;
    final result = await _request(base, '/v1/parent/children', token: token);
    if (prefs.getString(_parentUrl) != base ||
        prefs.getString(_parentToken) != token ||
        !await isShared(childId)) {
      throw const MilkSyncException(statusCode: 401, message: '家庭連線已變更，請重新開啟。');
    }
    final matches = (result['children'] as List).where(
      (e) => e['id'] == childId,
    );
    if (matches.isEmpty) return null;
    return Map<String, dynamic>.from(matches.first as Map);
  }

  static Future<Map<String, dynamic>> updateOuting({
    String? childId,
    required String action,
    required int expectedRevision,
    Map<String, dynamic>? store,
    DateTime? plannedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final child = childId == null;
    final urlKey = child ? _childUrl : _parentUrl;
    final tokenKey = child ? _childToken : _parentToken;
    final base = prefs.getString(urlKey), token = prefs.getString(tokenKey);
    if (base == null || token == null || (!child && !await isShared(childId))) {
      throw const MilkSyncException(statusCode: 401, message: '請先完成家庭連結。');
    }
    final result = await _request(
      base,
      child ? '/v1/child/outing' : '/v1/parent/outing',
      token: token,
      body: {
        'childId': ?childId,
        'action': action,
        'expectedRevision': expectedRevision,
        if (store != null)
          'store': {
            'name': store['name'],
            'address': store['address'] ?? '',
            'latitude': store['latitude'],
            'longitude': store['longitude'],
          },
        if (plannedAt != null) 'plannedAt': plannedAt.toUtc().toIso8601String(),
      },
    );
    if (prefs.getString(urlKey) != base || prefs.getString(tokenKey) != token) {
      throw const MilkSyncException(statusCode: 401, message: '家庭連線已變更，請重新開啟。');
    }
    final profile = Map<String, dynamic>.from(result['child'] as Map);
    if (child) await prefs.setString('milk_child_cache', jsonEncode(profile));
    return profile;
  }

  static Future<Map<String, dynamic>> childRecord(
    Map<String, dynamic> record,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final base = prefs.getString(_childUrl);
    final token = prefs.getString(_childToken);
    if (base == null || token == null) {
      throw const MilkSyncException(
        statusCode: HttpStatus.unauthorized,
        message: '連線已失效，請重新連結。',
      );
    }
    final response = await _request(
      base,
      '/v1/child/record',
      token: token,
      body: {'record': _safeRecord(record)},
    );
    final profile = Map<String, dynamic>.from(response['child'] as Map);
    // A request may finish after leaving or joining a different child. Its
    // response belongs to the old link and must not replace the current cache.
    if (prefs.getString(_childUrl) == base &&
        prefs.getString(_childToken) == token) {
      await prefs.setString('milk_child_cache', jsonEncode(profile));
    }
    return profile;
  }
}
