import 'package:town_pass/service/local_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

import 'package:town_pass/bean/message.dart';
import 'package:town_pass/gen/assets.gen.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class MessageViewController extends GetxController {
  List<MessageType> get tabTypeList => [
    MessageType.personal,
    MessageType.tcg,
    MessageType.system,
  ];

  final Rxn<MessageList> list = Rxn();
  static const preferenceKey = 'local_messages_v1';
  Future<void> _writes = Future.value();
  Future<T> _change<T>(T Function() action) {
    final operation = _writes.then((_) async {
      final backup = list.value == null
          ? null
          : MessageList.fromJson(list.value!.toJson());
      final result = action();
      try {
        final prefs = await SharedPreferences.getInstance();
        await LocalPersistence.checked(
          prefs,
          prefs.setString(
            preferenceKey,
            jsonEncode(list.value?.toJson() ?? {'data': []}),
          ),
        );
        list.refresh();
        return result;
      } catch (_) {
        list.value = backup;
        rethrow;
      }
    });
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> markRead(MessageItem item) => _change(() {
    item.hasRead = true;
  });
  Future<void> markAllRead(MessageType type) => _change(() {
    for (final message in messageList(type: type)) {
      message.hasRead = true;
    }
  });
  Future<List<MessageItem>> removeType(MessageType type) => _change(() {
    final removed = messageList(type: type);
    list.value = MessageList(
      data: list.value?.data.where((item) => item.type != type).toList() ?? [],
    );
    return removed;
  });
  Future<void> restore(List<MessageItem> restored) => _change(() {
    list.value = MessageList(
      data: [...list.value?.data ?? [], ...restored]
        ..sort((a, b) => b.datetime.compareTo(a.datetime)),
    );
  });

  bool _isLoading = true;

  bool get isLoading => _isLoading;

  List<MessageItem> messageList({required MessageType type}) {
    return list.value?.data.where((message) => message.type == type).toList() ??
        [];
  }

  int unreadCount({required MessageType type}) {
    return list.value?.data
            .where((message) => message.type == type && !message.hasRead)
            .length ??
        0;
  }

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> fetch() async {
    _isLoading = true;
    update();

    final prefs = await SharedPreferences.getInstance();
    final bundled = await rootBundle.loadString(Assets.mockData.message);
    try {
      list.value = MessageList.fromJson(
        jsonDecode(prefs.getString(preferenceKey) ?? bundled),
      );
    } catch (_) {
      list.value = MessageList.fromJson(jsonDecode(bundled));
    }

    _isLoading = false;
    update();
  }
}
