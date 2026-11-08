import 'package:town_pass/service/local_persistence.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';

class InvoiceReceiptView extends StatefulWidget {
  const InvoiceReceiptView({super.key});
  @override
  State<InvoiceReceiptView> createState() => _InvoiceReceiptViewState();
}

class _InvoiceReceiptViewState extends State<InvoiceReceiptView> {
  final carrier = TextEditingController();
  String? error, saved;
  bool busy = false;
  static const key = 'local_mobile_carrier_v1';
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() => carrier.text = saved = prefs.getString(key) ?? '');
      }
    });
  }

  @override
  void dispose() {
    carrier.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final value = carrier.text.trim().toUpperCase();
    if (!RegExp(r'^/[A-Z0-9.+-]{7}$').hasMatch(value)) {
      setState(() => error = '請輸入 / 開頭、共 8 碼的手機條碼。');
      return;
    }
    setState(() => busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await LocalPersistence.checked(prefs, prefs.setString(key, value));
      if (mounted) {
        setState(() {
          saved = value;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = '儲存失敗，請稍後重試。');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const TPAppBar(title: '發票收據'),
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
                  const Text(
                    '手機載具',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: TPColors.primary800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('儲存常用手機條碼，方便之後查找與使用。'),
                  const SizedBox(height: 20),
                  TextField(
                    controller: carrier,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 8,
                    decoration: InputDecoration(
                      labelText: '手機條碼',
                      hintText: '/ABC1234',
                      errorText: error,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : save,
                    style: FilledButton.styleFrom(
                      backgroundColor: TPColors.primary700,
                      foregroundColor: TPColors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('儲存手機載具'),
                  ),
                  if (saved != null && saved!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SelectableText(
                        '已儲存：$saved',
                        style: const TextStyle(
                          color: TPColors.primary800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '發票與收據紀錄',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Card(
            color: TPColors.white,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('目前沒有發票或收據紀錄。'),
            ),
          ),
        ],
      ),
    ),
  );
}
