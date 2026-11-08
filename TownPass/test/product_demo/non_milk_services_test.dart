import 'package:town_pass/service/local_persistence.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:town_pass/bean/message.dart';
import 'package:town_pass/page/local_service/local_service_view.dart';
import 'package:town_pass/page/message/message_view_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'local service preferences persist a receipt without personal fields',
    () async {
      final first = await LocalServiceStore.save('親子館', '週末上午');
      await LocalServiceStore.save('台北電台', '收藏服務資訊');
      final values = await LocalServiceStore.load();
      expect(values, hasLength(2));
      expect(values.last, first);
      expect(
        values.last.keys,
        unorderedEquals(['service', 'choice', 'savedAt', 'reference']),
      );
      expect(values.last['choice'], '週末上午');
    },
  );

  test('message read, category clearing and undo persist without mixing categories', () async {
    final controller = MessageViewController();
    final first = MessageItem(
      title: '個人提醒',
      datetime: DateTime.utc(2026, 11, 8),
      type: MessageType.personal,
      hasRead: false,
    );
    final second = MessageItem(
      title: '城市消息',
      datetime: DateTime.utc(2026, 11, 8),
      type: MessageType.tcg,
      hasRead: false,
    );
    controller.list.value = MessageList(data: [first, second]);
    await controller.markAllRead(MessageType.personal);
    expect(first.hasRead, isTrue);
    expect(second.hasRead, isFalse);
    final removed = await controller.removeType(MessageType.personal);
    expect(controller.messageList(type: MessageType.personal), isEmpty);
    expect(controller.messageList(type: MessageType.tcg).single, second);
    await controller.restore(removed);
    final prefs = await SharedPreferences.getInstance();
    final saved = MessageList.fromJson(
      jsonDecode(prefs.getString(MessageViewController.preferenceKey)!)
          as Map<String, dynamic>,
    );
    expect(saved.data, hasLength(2));
    expect(
      saved.data.singleWhere((m) => m.type == MessageType.personal).hasRead,
      isTrue,
    );
  });

  test('simultaneous local requests preserve every saved receipt', () async {
    await Future.wait([
      for (var i = 0; i < 12; i++) LocalServiceStore.save('服務$i', '選項$i'),
    ]);
    final saved = await LocalServiceStore.load();
    expect(saved, hasLength(12));
    expect(saved.map((item) => item['choice']).toSet(), {
      for (var i = 0; i < 12; i++) '選項$i',
    });
  });

  test(
    'a rejected platform save throws and leaves the persisted value intact',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('original', '保留的內容');
      await expectLater(
        LocalPersistence.checked(prefs, Future.value(false)),
        throwsStateError,
      );
      expect(prefs.getString('original'), '保留的內容');
      await LocalServiceStore.save('後續服務', '仍可儲存');
      expect((await LocalServiceStore.load()).single['choice'], '仍可儲存');
    },
  );

  testWidgets('local appointment preference produces a visible saved receipt', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LocalServiceView(title: '親子館', description: '選擇活動與偏好時段'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('週末上午'));
    await tester.pump();
    await tester.ensureVisible(find.text('儲存預約需求'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存預約需求'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    for (var i = 0; i < 20 && find.text('已儲存').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.scrollUntilVisible(
      find.text('已儲存'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('已儲存'), findsOneWidget);
    final stored = await tester.runAsync(LocalServiceStore.load);
    expect(stored!.single['choice'], '週末上午');
  });
}
