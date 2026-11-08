import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:town_pass/service/milk_reminder_target.dart';

class NotificationService extends GetxService {
  static int _id = 0;
  static final FlutterLocalNotificationsPlugin _notificationInstance =
      FlutterLocalNotificationsPlugin();

  Future<NotificationService> init() async {
    final launch = await _notificationInstance
        .getNotificationAppLaunchDetails();

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        );

    await _notificationInstance.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) =>
          MilkReminderNavigation.receive(response.payload),
    );
    if (launch?.didNotificationLaunchApp == true) {
      MilkReminderNavigation.receive(launch?.notificationResponse?.payload);
    }

    return this;
  }

  static Future<void> requestPermission() async {
    if (Platform.isAndroid) {
      await _notificationInstance
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _notificationInstance
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static Future<void> showNotification({String? title, String? content}) async {
    if ((await SharedPreferences.getInstance()).getBool(
          'notifications_enabled',
        ) ==
        false) {
      return;
    }
    await _notificationInstance.show(
      id: _id++,
      title: title,
      body: content,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'TownPass android notification id',
          'TownPass android notification channel name',
          importance: Importance.max,
          priority: Priority.max,
        ),
      ),
    );
  }
}
