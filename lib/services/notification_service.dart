import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);
  }

  static Future<void> showTrafficAlert({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'traffic_channel',
      'Traffic Alerts',
      channelDescription: 'Notifications for traffic conditions',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(id, title, body, details);
  }

  static Future<void> showSeriousTrafficAlert(double radiusMiles) async {
    await showTrafficAlert(
      title: 'Heavy Traffic Detected',
      body: 'Serious traffic congestion detected within ${radiusMiles.round()} miles. Consider alternative routes.',
    );
  }

  static Future<void> showCongestedTrafficAlert(double radiusMiles) async {
    await showTrafficAlert(
      title: 'Traffic Congestion',
      body: 'Moderate traffic congestion detected within ${radiusMiles.round()} miles.',
    );
  }

  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }
}