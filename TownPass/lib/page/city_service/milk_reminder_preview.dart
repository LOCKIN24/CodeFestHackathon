import 'package:flutter/material.dart';
import 'package:town_pass/service/milk_reminder_target.dart';

/// In-app preview. It does not send or schedule an OS notification.
class MilkReminderPreview extends StatelessWidget {
  const MilkReminderPreview({
    super.key,
    required this.targets,
    required this.onOpen,
    this.enabled = true,
  });
  final List<MilkReminderTarget> targets;
  final Future<void> Function(MilkReminderTarget) onOpen;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const Key('milk-reminder-preview'),
    onPressed: !enabled
        ? null
        : () async {
            final target = await showDialog<MilkReminderTarget>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('提醒預覽'),
                content: SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('選擇孩子，查看本週領取狀態。'),
                        const SizedBox(height: 12),
                        if (targets.isEmpty) const Text('本週的領取紀錄都已完成。'),
                        for (final target in targets)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${target.name} 本週鮮奶提醒'),
                            subtitle: const Text('點選查看這位孩子的狀態'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pop(context, target),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('關閉'),
                  ),
                ],
              ),
            );
            if (target != null && context.mounted) await onOpen(target);
          },
    icon: const Icon(Icons.notifications_active_outlined),
    label: Text('提醒預覽（${targets.length}）'),
  );
}
