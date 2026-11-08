import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/service/milk_reminder_service.dart';
import 'package:town_pass/util/tp_colors.dart';

/// Presents a notice on launch or resume until it is acknowledged that day.
class MilkDailyNotice extends StatefulWidget {
  const MilkDailyNotice({super.key, required this.child});
  final Widget child;
  @override
  State<MilkDailyNotice> createState() => _MilkDailyNoticeState();
}

class _MilkDailyNoticeState extends State<MilkDailyNotice>
    with WidgetsBindingObserver {
  static const _ackKey = 'milk_notice_ack_date';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onOpen());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onOpen();
  }

  Future<void> _onOpen() async {
    if (_checking) return;
    _checking = true;
    try {
      unawaited(MilkReminderService.refresh());
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toUtc().add(const Duration(hours: 8));
      final day =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (!mounted ||
          prefs.getString(_ackKey) == day ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    color: TPColors.primary100,
                    child: const Column(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: TPColors.white,
                          child: Icon(
                            Icons.local_drink_outlined,
                            size: 44,
                            color: TPColors.primary700,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '鮮奶週週報到！',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w600,
                            color: TPColors.primary800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '每週一瓶，別忘了兌領',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: TPColors.grayscale900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '攜帶符合資格的實體卡證至合作門市。每週一至週日可兌領一瓶，未使用的額度不累積。',
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: TPColors.grayscale800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '領取後回來留下紀錄，讓每週的小日常成為護照裡的收藏。',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: TPColors.grayscale700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: TPColors.primary700,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(54),
                            ),
                            onPressed: () async {
                              await prefs.setString(_ackKey, day);
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                            child: const Text(
                              '我知道了',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
