import 'package:town_pass/bean/message.dart';
import 'package:town_pass/gen/assets.gen.dart';
import 'package:town_pass/page/message/message_view_controller.dart';
import 'package:town_pass/util/extension/datetime.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_line.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:town_pass/util/tp_tab_view.dart';
import 'package:town_pass/util/tp_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

part 'package:town_pass/page/message/widget/_empty_message_widget.dart';

part 'package:town_pass/page/message/widget/_message_list_row.dart';

part 'package:town_pass/page/message/widget/_message_list_view.dart';

extension on MessageType {
  String get string {
    return switch (this) {
      MessageType.personal => '個人通知',
      MessageType.tcg => '市府訊息',
      MessageType.system => '系統訊息',
    };
  }
}

class MessageView extends GetView<MessageViewController> {
  const MessageView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: controller.tabTypeList.length,
      child: Scaffold(
        appBar: TPAppBar(
          title: '訊息',
          actions: [
            Builder(
              builder: (context) => IconButton(
                tooltip: '清除本分類訊息',
                icon: Assets.svg.iconTrashClose.svg(),
                onPressed: () async {
                  final messageController = controller;
                  final type =
                      controller.tabTypeList[DefaultTabController.of(context)
                          .index];
                  final yes = await showDialog<bool>(
                    context: context,
                    builder: (dialog) => AlertDialog(
                      backgroundColor: TPColors.white,
                      title: const Text('清除此分類訊息？'),
                      content: const Text('清除後可立即按「復原」還原訊息。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: const Text('清除'),
                        ),
                      ],
                    ),
                  );
                  if (yes != true) return;
                  List<MessageItem> removed;
                  try {
                    removed = await messageController.removeType(type);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('訊息未能清除，請稍後重試。')),
                      );
                    }
                    return;
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('訊息已清除'),
                        action: SnackBarAction(
                          label: '復原',
                          onPressed: () async {
                            try {
                              await messageController.restore(removed);
                            } catch (_) {
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('訊息未能復原，請稍後重試。'),
                                  ),
                                );
                            }
                          },
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        body: TPTabView(
          titles: controller.tabTypeList
              .map<String>((type) => type.string)
              .toList(),
          children: controller.tabTypeList
              .map<Widget>((type) => MessageListView(messageType: type))
              .toList(),
        ),
      ),
    );
  }
}
