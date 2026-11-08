import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:town_pass/service/notification_service.dart';
import 'package:town_pass/service/milk_reminder_target.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late bool launched;
  final target = MilkReminderTarget(
    childId: 'b' * 32,
    name: '孩子',
    role: 'parent',
    week: '2026-11-02',
  );
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    FlutterLocalNotificationsPlatform.instance =
        IOSFlutterLocalNotificationsPlugin();
    MilkReminderNavigation.pending.value = null;
    launched = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getNotificationAppLaunchDetails') {
            return {
              'notificationLaunchedApp': launched,
              if (launched)
                'notificationResponse': {
                  'notificationId': 71000,
                  'notificationResponseType': 0,
                  'payload': target.payload,
                },
            };
          }
          return true;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    MilkReminderNavigation.pending.value = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'native launch details retain destination before the navigator starts',
    () async {
      launched = true;
      await NotificationService().init();
      expect(MilkReminderNavigation.pending.value?.childId, 'b' * 32);
      expect(MilkReminderNavigation.pending.value?.role, 'parent');
    },
  );
  test('native notification callback dispatches targets and ignores unrelated payloads', () async {
    await NotificationService().init();
    expect(MilkReminderNavigation.pending.value, isNull);
    Future<void> deliver(String payload) async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('didReceiveNotificationResponse', {
                'notificationId': 71000,
                'notificationResponseType': 0,
                'payload': payload,
              }),
            ),
            (_) {},
          );
    }

    await deliver(target.payload);
    expect(MilkReminderNavigation.pending.value?.childId, 'b' * 32);
    MilkReminderNavigation.pending.value = null;
    await deliver('unrelated-app-notice');
    expect(MilkReminderNavigation.pending.value, isNull);
  });
}
