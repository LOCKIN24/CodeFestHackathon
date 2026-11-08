import 'package:town_pass/service/local_persistence.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/page/city_service/model/my_service_model.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:url_launcher/url_launcher.dart';

/// Local prototype requests. These receipts are drafts/preferences, never
/// government submissions, emergency dispatch, payments or medical bookings.
class LocalServiceStore {
  static const key = 'local_service_requests_v1';
  static Future<void> _writes = Future.value();
  static Future<List<Map<String, dynamic>>> _read() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> load() async {
    await _writes;
    return _read();
  }

  static Future<Map<String, dynamic>> save(String service, String choice) {
    final operation = _writes.then((_) async {
      final records = await _read();
      final now = DateTime.now();
      final entry = {
        'service': service,
        'choice': choice,
        'savedAt': now.toIso8601String(),
        'reference': 'TP${now.microsecondsSinceEpoch}',
      };
      records.insert(0, entry);
      final prefs = await SharedPreferences.getInstance();
      await LocalPersistence.checked(
        prefs,
        prefs.setString(key, jsonEncode(records)),
      );
      return entry;
    });
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}

Future<void> openCatalogService(
  BuildContext context,
  MyServiceItem item,
) async {
  if (item.destinationUrl.isNotEmpty) {
    await TPRoute.openUri(
      uri: item.destinationUrl,
      forceTitle: item.forceWebViewTitle,
    );
  } else {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LocalServiceView(title: item.title, description: item.description),
      ),
    );
  }
}

class LocalServiceCatalogView extends StatelessWidget {
  const LocalServiceCatalogView({super.key, this.category});
  final MyServiceCategory? category;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: TPAppBar(title: category?.title ?? '市政服務'),
    backgroundColor: TPColors.grayscale50,
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final id in MyServiceItemId.values.where(
          (id) => category == null || id.item.category == category,
        ))
          Card(
            color: TPColors.white,
            surfaceTintColor: Colors.transparent,
            child: ListTile(
              leading: SizedBox(width: 32, height: 32, child: id.item.icon),
              title: Text(id.item.title),
              subtitle: Text(id.item.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openCatalogService(context, id.item),
            ),
          ),
      ],
    ),
  );
}

class LocalServiceView extends StatefulWidget {
  const LocalServiceView({
    super.key,
    required this.title,
    required this.description,
  });
  final String title, description;
  @override
  State<LocalServiceView> createState() => _LocalServiceViewState();
}

class _LocalServiceViewState extends State<LocalServiceView> {
  String? choice, error;
  Map<String, dynamic>? saved;
  bool busy = false;
  bool get appointment =>
      widget.title.contains('預約') ||
      widget.title.contains('掛號') ||
      widget.title.contains('親子館');
  bool get contact => widget.title == '1999' || widget.title.contains('警政');
  List<String> get choices => appointment
      ? ['平日上午', '平日下午', '週末上午']
      : widget.title.contains('投票') || widget.title.contains('調查')
      ? ['城市綠化', '交通改善', '親子空間']
      : ['收藏服務資訊'];
  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await LocalServiceStore.save(
        widget.title,
        choice ?? choices.first,
      );
      if (mounted) setState(() => saved = value);
    } catch (_) {
      if (mounted) setState(() => error = '無法儲存，請稍後再試。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> call(String number) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: TPColors.white,
        title: Text('撥打 $number？'),
        content: const Text('將開啟手機的電話功能，由你確認撥出。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('開啟電話'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (!await launchUrl(Uri(scheme: 'tel', path: number))) {
        throw StateError('call');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('請使用電話撥打 $number')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: TPAppBar(title: widget.title),
    backgroundColor: TPColors.grayscale50,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: TPColors.white,
            surfaceTintColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: TPColors.primary800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.description),
                  const SizedBox(height: 24),
                  if (contact) ...[
                    Text(
                      widget.title == '1999'
                          ? '市民服務專線 1999'
                          : '緊急報案請撥打 110；緊急救護請撥打 119。',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          call(widget.title == '1999' ? '1999' : '110'),
                      icon: const Icon(Icons.phone_outlined),
                      label: const Text('開啟電話選項'),
                    ),
                  ] else ...[
                    Text(
                      appointment ? '選擇偏好時段' : '服務選項',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<String>(
                      groupValue: choice ?? choices.first,
                      onChanged: (value) {
                        if (!busy) setState(() => choice = value);
                      },
                      child: Column(
                        children: [
                          for (final option in choices)
                            RadioListTile<String>(
                              value: option,
                              enabled: !busy,
                              activeColor: TPColors.primary700,
                              title: Text(option),
                            ),
                        ],
                      ),
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: const TextStyle(color: TPColors.red700),
                      ),
                    FilledButton(
                      onPressed: busy ? null : save,
                      style: FilledButton.styleFrom(
                        backgroundColor: TPColors.primary700,
                        foregroundColor: TPColors.white,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: Text(
                        busy
                            ? '儲存中…'
                            : appointment
                            ? '儲存預約需求'
                            : choices.length > 1
                            ? '儲存我的選擇'
                            : '收藏服務資訊',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (saved != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Card(
                color: TPColors.white,
                child: ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: TPColors.primary700,
                  ),
                  title: const Text('已儲存'),
                  subtitle: Text('${saved!['choice']}\n可在「歷程與授權管理」查看。'),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
