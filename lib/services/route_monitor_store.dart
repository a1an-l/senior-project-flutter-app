import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RouteMonitorConfig {
  const RouteMonitorConfig({
    required this.enabled,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.autoResetBaseline,
    required this.autoResetIntervalMinutes,
    required this.lastResetAtMs,
  });

  final bool enabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final bool autoResetBaseline; // when true, baseline will be updated periodically
  final int autoResetIntervalMinutes; // interval in minutes between baseline resets
  final int lastResetAtMs; // epoch ms when baseline was last reset (0 = never)

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
        'autoResetBaseline': autoResetBaseline,
        'autoResetIntervalMinutes': autoResetIntervalMinutes,
        'lastResetAtMs': lastResetAtMs,
      };

  factory RouteMonitorConfig.fromJson(Map<String, dynamic> json) {
    return RouteMonitorConfig(
      enabled: json['enabled'] as bool? ?? true,
      startHour: (json['startHour'] as num?)?.toInt() ?? 6,
      startMinute: (json['startMinute'] as num?)?.toInt() ?? 0,
      endHour: (json['endHour'] as num?)?.toInt() ?? 22,
      endMinute: (json['endMinute'] as num?)?.toInt() ?? 0,
      autoResetBaseline: json['autoResetBaseline'] as bool? ?? false,
      // Support older stored configs that used hours; prefer minutes when present
      autoResetIntervalMinutes: json['autoResetIntervalMinutes'] != null
          ? (json['autoResetIntervalMinutes'] as num).toInt()
          : ((json['autoResetIntervalHours'] as num?)?.toInt() ?? 24) * 60,
      lastResetAtMs: (json['lastResetAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  bool isActiveAt(DateTime now) {
    final int nowMinutes = now.hour * 60 + now.minute;
    final int startMinutes = startHour * 60 + startMinute;
    final int endMinutes = endHour * 60 + endMinute;

    if (startMinutes <= endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    }
    return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
  }

  String formatWindow() {
    String _format(int hour, int minute) {
      final period = hour >= 12 ? 'pm' : 'am';
      final hour12 = hour % 12 == 0 ? 12 : hour % 12;
      final minuteText = minute.toString().padLeft(2, '0');
      return '$hour12:$minuteText $period';
    }

    return '${_format(startHour, startMinute)} - ${_format(endHour, endMinute)}';
  }

  static RouteMonitorConfig defaultConfig() => const RouteMonitorConfig(
        enabled: true,
        startHour: 6,
        startMinute: 0,
        endHour: 22,
        endMinute: 0,
        autoResetBaseline: false,
        autoResetIntervalMinutes: 24 * 60,
        lastResetAtMs: 0,
      );
}

class RouteMonitorStore {
  static const _key = 'route_monitor_configs';

  static Future<Map<String, RouteMonitorConfig>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) {
      return MapEntry(key, RouteMonitorConfig.fromJson(value as Map<String, dynamic>));
    });
  }

  static Future<void> saveAll(Map<String, RouteMonitorConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = configs.map((key, value) => MapEntry(key, value.toJson()));
    await prefs.setString(_key, jsonEncode(encoded));
  }

  static Future<void> save(String label, RouteMonitorConfig config) async {
    final all = await loadAll();
    all[label] = config;
    await saveAll(all);
  }

  static Future<RouteMonitorConfig?> load(String label) async {
    final all = await loadAll();
    return all[label];
  }

  static Future<void> ensureConfigsForLabels(List<String> labels) async {
    final all = await loadAll();
    var updated = false;
    for (final label in labels) {
      if (!all.containsKey(label)) {
        all[label] = RouteMonitorConfig.defaultConfig();
        updated = true;
      }
    }
    if (updated) {
      await saveAll(all);
    }
  }
}
