import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/service/milk_family_store.dart';
import 'package:town_pass/service/milk_family_sync.dart';

class MilkDemoSession {
  const MilkDemoSession(this.url, this.token, this.children);
  final String url, token;
  final List<Map<String, dynamic>> children;

  MilkDemoSession replaceChild(Map<String, dynamic> child) => MilkDemoSession(
    url,
    token,
    children.map((c) => c['id'] == child['id'] ? child : c).toList(),
  );
}

class MilkDemoResult {
  const MilkDemoResult(this.result, this.child);
  final String result;
  final Map<String, dynamic> child;
}

/// Explicit fake POS transports for the hackathon product experience.
/// Isolated local/HTTP sessions never replace the ordinary family. The separate
/// family-local mode atomically records against the parent's current family;
/// it never transmits card numbers or changes connection credentials.
class MilkRedemptionDemo {
  static const preferenceKey = 'milk_redemption_demo_session_v1';
  static const localAddress = 'local';
  static const familyLocalAddress = 'family-local';
  static const familyEventKey = 'milk_family_demo_events_v1';
  static Future<void> _localWrites = Future.value();

  static Future<T> _local<T>(Future<T> Function() action) {
    final task = _localWrites.catchError((Object _) {}).then((_) => action());
    _localWrites = task.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return task;
  }

  static Future<void> _savePreference(
    String key,
    Map<String, dynamic> value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(key);
    try {
      if (await prefs.setString(key, jsonEncode(value))) return;
    } catch (_) {}
    // The legacy cache changes before disk success. Roll it back on failure.
    try {
      if (previous == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, previous);
      }
    } catch (_) {}
    throw StateError('無法儲存領取紀錄，請重試。');
  }

  static Future<void> _saveLocal(Map<String, dynamic> value) =>
      _savePreference(preferenceKey, value);

  static Map<String, dynamic> _familyProfile(MilkChild child) => {
    'id': child.id,
    'alias': child.name,
    'cardRef': 'FAMILY-${child.id}',
    'records': child.records,
    if (child.outing != null) 'outing': child.outing,
  };

  /// Explicit local fake POS for the same family shown on the parent screen.
  /// It never calls HTTP or creates/replaces children or parent credentials.
  static Future<MilkDemoSession> openFamily() async {
    if (await MilkFamilySync.isChild) throw StateError('請由家長帳號開啟領取服務。');
    final family = await MilkFamilyStore.load();
    return MilkDemoSession(
      familyLocalAddress,
      'family-local-v1',
      family.map(_familyProfile).toList(),
    );
  }

  static Future<Map<String, dynamic>> _familyEvents() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      familyEventKey,
    );
    return raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<MilkDemoResult> _redeemFamily(
    MilkDemoSession session,
    String cardRef,
    String product, {
    required bool repeat,
  }) => _local(() async {
    if (product != '鮮奶' && product != '豆漿') {
      throw const FormatException('請選擇鮮奶或豆漿。');
    }
    final current = await openFamily();
    if (session.token != current.token) throw StateError('家庭資料已更新，請重新開啟。');
    final matches = current.children.where((c) => c['cardRef'] == cardRef);
    if (matches.isEmpty) throw StateError('這位孩子已移除，請重新開啟。');
    final id = matches.single['id'] as String;
    final events = await _familyEvents();
    final old = events[id] as Map?;
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final monday = DateTime.utc(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1))
        .toIso8601String()
        .substring(0, 10);
    if (repeat && old == null) throw StateError('尚無可重送的領取紀錄。');
    final event = old != null && (repeat || old['week'] == monday)
        ? Map<String, dynamic>.from(old)
        : {
            'transactionId': MilkChild.newId(),
            'week': monday,
            'product': product,
          };
    if (event['week'] != monday) {
      final child = matches.single;
      if ((child['records'] as List).any(
        (r) => r['transactionId'] == event['transactionId'],
      )) {
        return MilkDemoResult('duplicate_transaction', child);
      }
      throw StateError('這筆紀錄已過期，請重新開啟。');
    }
    final existing = (matches.single['records'] as List).where(
      (r) => r['week'] == monday,
    );
    if (existing.isNotEmpty) {
      return MilkDemoResult(
        existing.first['transactionId'] == event['transactionId']
            ? 'duplicate_transaction'
            : 'already_recorded',
        matches.single,
      );
    }
    events[id] = event;
    // Commit identity first so a failed record write retries the same event.
    await _savePreference(familyEventKey, events);
    String two(int n) => n.toString().padLeft(2, '0');
    final day = '${now.year}-${two(now.month)}-${two(now.day)}';
    final record = <String, dynamic>{
      'week': monday,
      'product': event['product'],
      'date': '${day.replaceAll('-', '/')} ${two(now.hour)}:${two(now.minute)}',
      'source': 'demo_transaction',
      'transactionId': event['transactionId'],
      'confirmedAt':
          '${day}T${two(now.hour)}:${two(now.minute)}:${two(now.second)}+08:00',
    };
    final result = await MilkFamilyStore.recordDemoPickup(id, record);
    return MilkDemoResult(result.result, _familyProfile(result.child));
  });

  static MilkDemoSession _localSession(Map<String, dynamic> saved) =>
      MilkDemoSession(
        localAddress,
        saved['token'] as String,
        _children(saved['children']),
      );

  static Future<Map<String, dynamic>> _requireLocal(
    MilkDemoSession session,
  ) async {
    final saved = await _saved();
    if (saved == null ||
        saved['url'] != localAddress ||
        saved['token'] != session.token) {
      throw StateError('家庭資料已更新，請重新開啟。');
    }
    return saved;
  }

  static Future<MilkDemoSession> _openLocal({required bool fresh}) =>
      _local(() async {
        final saved = fresh ? null : await _saved();
        if (saved != null) {
          if (saved['url'] != localAddress) {
            throw const FormatException('切換服務前請先重新建立家庭。');
          }
          return _localSession(saved);
        }
        final value = <String, dynamic>{
          'url': localAddress,
          'token': MilkChild.newId(),
          'events': <String, dynamic>{},
          'children': [
            for (var i = 1; i <= 2; i++)
              {
                'id': MilkChild.newId(),
                'alias': '孩子$i',
                'cardRef': 'DEMO-CARD-0$i',
                'records': <Map<String, dynamic>>[],
              },
          ],
        };
        await _saveLocal(value);
        return _localSession(value);
      });

  static Future<MilkDemoResult> _redeemLocal(
    MilkDemoSession session,
    String cardRef,
    String product, {
    required bool repeat,
  }) => _local(() async {
    if (product != '鮮奶' && product != '豆漿') {
      throw const FormatException('請選擇鮮奶或豆漿。');
    }
    final saved = await _requireLocal(session);
    final children = _children(saved['children']);
    final matches = children.where((c) => c['cardRef'] == cardRef);
    if (matches.isEmpty) throw const FormatException('找不到這位孩子，請重新開啟。');
    final child = matches.single;
    final events = Map<String, dynamic>.from(saved['events'] as Map);
    final old = events[cardRef] as Map?;
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final monday = DateTime.utc(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1))
        .toIso8601String()
        .substring(0, 10);
    if (repeat && old == null) throw StateError('尚無可重播的領取紀錄。');
    final event = old != null && (repeat || old['week'] == monday)
        ? Map<String, dynamic>.from(old)
        : {
            'transactionId': MilkChild.newId(),
            'cardRef': cardRef,
            'product': product,
            'week': monday,
          };
    final records = (child['records'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    if (records.any((r) => r['transactionId'] == event['transactionId'])) {
      return MilkDemoResult('duplicate_transaction', child);
    }
    if (records.any((r) => r['week'] == monday)) {
      return MilkDemoResult('already_recorded', child);
    }
    if (event['week'] != monday) throw StateError('這筆紀錄已過期，請重新開啟。');
    String two(int n) => n.toString().padLeft(2, '0');
    final day = '${now.year}-${two(now.month)}-${two(now.day)}';
    final time = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    records.insert(0, {
      'week': monday,
      'product': event['product'],
      'date': '${day.replaceAll('-', '/')} ${two(now.hour)}:${two(now.minute)}',
      'source': 'demo_transaction',
      'transactionId': event['transactionId'],
      'confirmedAt': '${day}T$time+08:00',
    });
    child['records'] = records;
    events[cardRef] = event;
    saved['events'] = events;
    saved['children'] = children;
    await _saveLocal(saved);
    return MilkDemoResult('accepted', child);
  });

  static Uri _base(String value) {
    final uri = Uri.tryParse(value.trim());
    final ip = uri == null ? null : InternetAddress.tryParse(uri.host);
    if (uri == null ||
        uri.scheme != 'http' ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment ||
        ip == null ||
        ip.type != InternetAddressType.IPv4) {
      throw const FormatException('請輸入電腦的區網網址，例如 http://192.168.1.2:8766');
    }
    final p = ip.address.split('.').map(int.parse).toList();
    if (!(p[0] == 127 ||
        p[0] == 10 ||
        p[0] == 192 && p[1] == 168 ||
        p[0] == 172 && p[1] >= 16 && p[1] <= 31)) {
      throw const FormatException('展示服務只允許私人區網位址。');
    }
    return uri.replace(path: '');
  }

  static Future<Map<String, dynamic>> _request(
    String base,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = _base(base).replace(path: path);
      final request = body == null
          ? await client.getUrl(uri)
          : await client.postUrl(uri);
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        final bytes = utf8.encode(jsonEncode(body));
        request.headers.contentType = ContentType.json;
        request.contentLength = bytes.length;
        request.add(bytes);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 7),
      );
      final value = jsonDecode(
        await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 7)),
      ) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw MilkSyncException(
          statusCode: response.statusCode,
          message: value['error']?.toString() ?? '展示服務連線失敗',
        );
      }
      return value;
    } finally {
      client.close(force: true);
    }
  }

  static List<Map<String, dynamic>> _children(dynamic value) =>
      (value as List).map((c) => Map<String, dynamic>.from(c as Map)).toList();

  static Future<Map<String, dynamic>?> _saved() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      preferenceKey,
    );
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<String?> savedUrl() async =>
      (await _saved())?['url'] as String?;

  static Future<MilkDemoSession> open(
    String address, {
    bool fresh = false,
  }) async {
    if (address.trim() == localAddress) return _openLocal(fresh: fresh);
    final base = _base(address).toString();
    final saved = fresh ? null : await _saved();
    if (!fresh && saved != null) {
      if (saved['url'] != base) {
        throw const FormatException('切換網址前請按「重建展示家庭」；原有學生資料不會變更。');
      }
      return refresh(MilkDemoSession(base, saved['token'] as String, const []));
    }
    final result = await _request(base, '/v1/demo/families', body: {});
    final token = result['parentToken'] as String;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      preferenceKey,
      jsonEncode({'url': base, 'token': token, 'events': <String, dynamic>{}}),
    )) {
      throw StateError('無法保存展示連線');
    }
    return MilkDemoSession(base, token, _children(result['children']));
  }

  static Future<MilkDemoSession> refresh(MilkDemoSession session) async {
    if (session.url == familyLocalAddress) return openFamily();
    if (session.url == localAddress) {
      return _local(() async => _localSession(await _requireLocal(session)));
    }
    final result = await _request(
      session.url,
      '/v1/parent/children',
      token: session.token,
    );
    return MilkDemoSession(
      session.url,
      session.token,
      _children(result['children']),
    );
  }

  static Future<Map<String, dynamic>?> lastEvent(
    MilkDemoSession session,
    String cardRef,
  ) async {
    if (session.url == familyLocalAddress) {
      await _localWrites;
      final current = await openFamily();
      final child = current.children.where((c) => c['cardRef'] == cardRef);
      if (session.token != current.token || child.isEmpty) return null;
      final event = (await _familyEvents())[child.single['id']];
      if (event is Map) {
        final record = (child.single['records'] as List).where(
          (r) => r['week'] == event['week'],
        );
        if (record.isNotEmpty &&
            record.first['transactionId'] != event['transactionId']) {
          return null;
        }
      }
      return event is Map
          ? {...Map<String, dynamic>.from(event), 'cardRef': cardRef}
          : null;
    }
    if (session.url == localAddress) await _localWrites;
    final saved = await _saved();
    if (saved?['token'] != session.token || saved?['url'] != session.url) {
      return null;
    }
    final raw = (saved?['events'] as Map?)?[cardRef];
    return raw == null ? null : Map<String, dynamic>.from(raw as Map);
  }

  static Future<MilkDemoResult> redeem(
    MilkDemoSession session,
    String cardRef,
    String product, {
    bool repeat = false,
  }) async {
    if (session.url == familyLocalAddress) {
      return _redeemFamily(session, cardRef, product, repeat: repeat);
    }
    if (session.url == localAddress) {
      return _redeemLocal(session, cardRef, product, repeat: repeat);
    }
    final saved = await _saved();
    if (saved == null ||
        saved['token'] != session.token ||
        saved['url'] != session.url) {
      throw StateError('展示連線已變更，請重新載入。');
    }
    final events = Map<String, dynamic>.from(saved['events'] as Map);
    final old = events[cardRef] as Map?;
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final monday = DateTime.utc(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1))
        .toIso8601String()
        .substring(0, 10);
    if (repeat && old == null) throw StateError('尚無可重送的展示交易。');
    // Persist BEFORE sending. A timed-out POST may have succeeded; retry the
    // identical ID and payload, including after leaving/reopening this screen.
    final event = old != null && (repeat || old['week'] == monday)
        ? Map<String, dynamic>.from(old)
        : {
            'transactionId': MilkChild.newId(),
            'cardRef': cardRef,
            'product': product,
            'week': monday,
          };
    events[cardRef] = event;
    saved['events'] = events;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(preferenceKey, jsonEncode(saved))) {
      throw StateError('無法保存交易識別碼，尚未傳送。');
    }
    final result = await _request(
      session.url,
      '/v1/demo/transactions',
      token: session.token,
      body: {
        for (final key in ['transactionId', 'cardRef', 'product'])
          key: event[key],
      },
    );
    return MilkDemoResult(
      result['result'] as String,
      Map<String, dynamic>.from(result['child'] as Map),
    );
  }
}
