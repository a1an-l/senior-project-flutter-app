import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  Future<void> init({required void Function(String? payload) onTap}) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: android);
    await plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
  }

  Future<void> requestAndroidPermissionIfNeeded() async {
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  Future<void> showTrafficAlert({
    required String title,
    required String body,
    required String payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'traffic_alerts',
      'Traffic Alerts',
      channelDescription: 'Traffic delay alerts and reroutes',
      importance: Importance.max,
      priority: Priority.high,
    );

    await plugin.show(
      1001,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }
}
