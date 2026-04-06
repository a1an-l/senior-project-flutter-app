import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'traffic_detection_service.dart';
import 'notification_service.dart';

// Simple timer-based background service for testing
class BackgroundTrafficService {
  static Timer? _trafficTimer;
  static const String _prefsEnabledKey = 'traffic_detection_enabled';
  static const String _prefsIntervalKey = 'traffic_check_interval_minutes';
  static const String _prefsRadiusKey = 'detection_radius_miles';
  static const String _prefsNotifyOnlySeriousKey = 'notify_only_serious';

  static Future<void> initialize() async {
    try {
      print('[TrafficDetection] Initializing notification service...');
      await NotificationService.initialize();
      print('[TrafficDetection] Notification service initialized successfully');

      // Check if monitoring was previously enabled and restart it
      final enabled = await isTrafficMonitoringEnabled();
      if (enabled) {
        print('[TrafficDetection] Restarting previously enabled traffic monitoring');
        final settings = await getTrafficSettings();
        await startTrafficMonitoring(
          intervalMinutes: settings['intervalMinutes'],
          radiusMiles: settings['radiusMiles'],
          notifyOnlySerious: settings['notifyOnlySerious'],
        );
      }
    } catch (e, stackTrace) {
      print('[TrafficDetection] Error initializing services: $e');
      print('[TrafficDetection] Stack trace: $stackTrace');
    }
  }

  static Future<void> performTrafficCheck() async {
    try {
      print('[TrafficDetection] Starting traffic check...');

      // Check if traffic detection is enabled
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefsEnabledKey) ?? false;
      if (!enabled) {
        print('[TrafficDetection] Traffic detection is disabled');
        return;
      }

      // Get user location
      print('[TrafficDetection] Getting current location...');
      final position = await _getCurrentPosition();
      if (position == null) {
        print('[TrafficDetection] Could not get location');
        return;
      }
      print('[TrafficDetection] Location obtained: ${position.latitude}, ${position.longitude}');

      // Get settings
      final radius = prefs.getDouble(_prefsRadiusKey) ?? 2.0;
      final notifyOnlySerious = prefs.getBool(_prefsNotifyOnlySeriousKey) ?? true;
      print('[TrafficDetection] Settings - Radius: ${radius}mi, NotifyOnlySerious: $notifyOnlySerious');

      // Check for serious traffic
      print('[TrafficDetection] Checking for traffic conditions...');
      final hasSerious = await TrafficDetectionService.hasSeriousTraffic(position, radius);
      print('[TrafficDetection] Serious traffic detected: $hasSerious');

      if (hasSerious) {
        print('[TrafficDetection] Sending serious traffic notification');
        await NotificationService.showSeriousTrafficAlert(radius);
      } else if (!notifyOnlySerious) {
        // Check for any congestion
        final worstCondition = await TrafficDetectionService.getWorstTrafficCondition(position, radius);
        print('[TrafficDetection] Worst traffic condition: ${worstCondition.toString()}');
        if (worstCondition == TrafficCondition.congested) {
          print('[TrafficDetection] Sending congested traffic notification');
          await NotificationService.showCongestedTrafficAlert(radius);
        }
      }

      print('[TrafficDetection] Traffic check completed successfully');
    } catch (e) {
      print('[TrafficDetection] Error in traffic check: $e');
    }
  }

  static Future<Position?> _getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  static Future<void> startTrafficMonitoring({
    int intervalMinutes = 15,
    double radiusMiles = 2.0,
    bool notifyOnlySerious = true,
  }) async {
    print('[TrafficDetection] Starting traffic monitoring...');
    print('[TrafficDetection] Interval: ${intervalMinutes}min, Radius: ${radiusMiles}mi, NotifyOnlySerious: $notifyOnlySerious');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabledKey, true);
    await prefs.setInt(_prefsIntervalKey, intervalMinutes);
    await prefs.setDouble(_prefsRadiusKey, radiusMiles);
    await prefs.setBool(_prefsNotifyOnlySeriousKey, notifyOnlySerious);

    // Cancel existing timer if running
    _trafficTimer?.cancel();

    // Start new timer
    _trafficTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (timer) async {
        await performTrafficCheck();
      },
    );

    print('[TrafficDetection] Traffic monitoring started with timer');
  }

  static Future<void> stopTrafficMonitoring() async {
    print('[TrafficDetection] Stopping traffic monitoring');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabledKey, false);

    _trafficTimer?.cancel();
    _trafficTimer = null;
    print('[TrafficDetection] Traffic monitoring stopped');
  }

  static Future<bool> isTrafficMonitoringEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsEnabledKey) ?? false;
  }

  static Future<Map<String, dynamic>> getTrafficSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool(_prefsEnabledKey) ?? false,
      'intervalMinutes': prefs.getInt(_prefsIntervalKey) ?? 15,
      'radiusMiles': prefs.getDouble(_prefsRadiusKey) ?? 2.0,
      'notifyOnlySerious': prefs.getBool(_prefsNotifyOnlySeriousKey) ?? true,
    };
  }

  static Future<void> updateTrafficSettings({
    int? intervalMinutes,
    double? radiusMiles,
    bool? notifyOnlySerious,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (intervalMinutes != null) {
      await prefs.setInt(_prefsIntervalKey, intervalMinutes);
    }
    if (radiusMiles != null) {
      await prefs.setDouble(_prefsRadiusKey, radiusMiles);
    }
    if (notifyOnlySerious != null) {
      await prefs.setBool(_prefsNotifyOnlySeriousKey, notifyOnlySerious);
    }

    // Restart monitoring with new settings if enabled
    final enabled = await isTrafficMonitoringEnabled();
    if (enabled) {
      await stopTrafficMonitoring();
      final settings = await getTrafficSettings();
      await startTrafficMonitoring(
        intervalMinutes: settings['intervalMinutes'],
        radiusMiles: settings['radiusMiles'],
        notifyOnlySerious: settings['notifyOnlySerious'],
      );
    }
  }
}