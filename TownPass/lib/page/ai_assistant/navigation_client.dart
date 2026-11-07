import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class NavigationException implements Exception {
  const NavigationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class NavigationResult {
  NavigationResult(
    this.choice,
    this.preview, {
    this.navigationEligible = false,
  });
  final bool navigationEligible;
  final Map<String, dynamic> choice;
  final Map<String, dynamic> preview;

  factory NavigationResult.parse(Object? value) {
    if (value is! Map || value['choice'] is! Map || value['preview'] is! Map) {
      throw const NavigationException('服務回傳格式有誤。');
    }
    final choice = Map<String, dynamic>.from(value['choice'] as Map);
    final preview = Map<String, dynamic>.from(value['preview'] as Map);
    if (choice['action_allowed'] != false ||
        choice['intent'] is! String ||
        !const {
          'preview',
          'incomplete',
          'clarify',
          'rejected',
        }.contains(preview['status'])) {
      throw const NavigationException('服務回傳內容無效，無法顯示預覽。');
    }
    return NavigationResult(
      choice,
      preview,
      navigationEligible: value['navigation_eligible'] == true,
    );
  }
}

abstract class NavigationClient {
  Future<NavigationResult> request(String query);
}

class LocalNavigationClient implements NavigationClient {
  LocalNavigationClient({
    String? baseUrl,
    String? token,
    HttpClient? client,
    this.timeout = const Duration(seconds: 60),
  }) : baseUrl = baseUrl ?? const String.fromEnvironment('NAV_LAB_URL'),
       token = token ?? const String.fromEnvironment('NAV_LAB_TOKEN'),
       _client = client ?? HttpClient();
  final String baseUrl;
  final String token;
  final HttpClient _client;
  final Duration timeout;

  void close() => _client.close(force: true);

  static bool isPrivateHost(String host) {
    final ip = InternetAddress.tryParse(host);
    if (ip == null || ip.type != InternetAddressType.IPv4) return false;
    final b = ip.rawAddress;
    return b[0] == 127 ||
        b[0] == 10 ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
        (b[0] == 192 && b[1] == 168);
  }

  @override
  Future<NavigationResult> request(String query) async {
    final uri = Uri.tryParse(baseUrl);
    if (!kDebugMode ||
        uri == null ||
        uri.scheme != 'http' ||
        !isPrivateHost(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        token.length < 32) {
      throw const NavigationException('請在開發模式設定本機導航服務網址和驗證碼。');
    }
    try {
      final response = await (() async {
        final request = await _client.postUrl(
          uri.replace(path: '/api/mobile/preview'),
        );
        request.followRedirects = false;
        request.headers.contentType = ContentType.json;
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        final body = utf8.encode(jsonEncode({'query': query}));
        request.contentLength = body.length;
        request.add(body);
        final response = await request.close();
        final text = await response.transform(utf8.decoder).join();
        if (response.statusCode != 200) {
          throw NavigationException('無法連線到導航服務（${response.statusCode}）。');
        }
        return NavigationResult.parse(jsonDecode(text));
      })().timeout(timeout);
      return response;
    } on TimeoutException {
      throw const NavigationException('連線逾時，請確認 Mac 與本地模型正在運作。');
    } on SocketException {
      throw const NavigationException('無法連線到 Mac，請確認 Wi-Fi 與導航服務設定。');
    } on FormatException {
      throw const NavigationException('服務回傳格式有誤。');
    }
  }
}
