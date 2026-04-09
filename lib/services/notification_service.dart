import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  // Singleton (from main)
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  // Initialization (merged)
  Future<void> init({
    required void Function(String? payload) onTap,
  }) async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) =>
          onTap(response.payload),
    );
  }

  // Android permission (from main)
  Future<void> requestAndroidPermissionIfNeeded() async {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  // Base notification (merged: payload + iOS + better config)
  Future<void> showTrafficAlert({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'traffic_alerts',
      'Traffic Alerts',
      channelDescription: 'Traffic delay alerts and reroutes',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await plugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Prebuilt alerts (from Traffic-Radius)
  Future<void> showSeriousTrafficAlert(double radiusMiles) async {
    await showTrafficAlert(
      id: 1001,
      title: 'Heavy Traffic Detected',
      body:
          'Serious traffic congestion detected within ${radiusMiles.round()} miles. Consider alternative routes.',
      payload: 'serious_traffic',
    );
  }

  Future<void> showCongestedTrafficAlert(double radiusMiles) async {
    await showTrafficAlert(
      id: 1002,
      title: 'Traffic Congestion',
      body:
          'Moderate traffic congestion detected within ${radiusMiles.round()} miles.',
      payload: 'moderate_traffic',
    );
  }

  // Cancel methods (from Traffic-Radius)
  Future<void> cancelAllNotifications() async {
    await plugin.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await plugin.cancel(id);
  }
}