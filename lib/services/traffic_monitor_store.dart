import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TrafficMonitorConfig {
  const TrafficMonitorConfig({
    required this.destLat,
    required this.destLng,
    required this.destName,
    required this.normalSeconds,
    required this.thresholdSeconds,
  });

  final double destLat;
  final double destLng;
  final String destName;
  final int normalSeconds;
  final int thresholdSeconds;

  Map<String, dynamic> toJson() => {
        'destLat': destLat,
        'destLng': destLng,
        'destName': destName,
        'normalSeconds': normalSeconds,
        'thresholdSeconds': thresholdSeconds,
      };

  static TrafficMonitorConfig fromJson(Map<String, dynamic> json) {
    return TrafficMonitorConfig(
      destLat: (json['destLat'] as num).toDouble(),
      destLng: (json['destLng'] as num).toDouble(),
      destName: json['destName'] as String,
      normalSeconds: (json['normalSeconds'] as num).toInt(),
      thresholdSeconds: (json['thresholdSeconds'] as num).toInt(),
    );
  }
}

class TrafficMonitorStore {
  static const _key = 'traffic_monitor_config';

  static Future<void> save(TrafficMonitorConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(config.toJson()));
  }

  static Future<TrafficMonitorConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return TrafficMonitorConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

