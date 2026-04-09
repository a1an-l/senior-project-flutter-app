import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HiWayNotification {
  HiWayNotification({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.createdAtMs,
    required this.read,
    required this.urgent,
  });

  final String id;
  final String title;
  final String subtitle;
  final String detail;
  final int createdAtMs;
  final bool read;
  final bool urgent;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'detail': detail,
        'createdAtMs': createdAtMs,
        'read': read,
        'urgent': urgent,
      };

  static HiWayNotification fromJson(Map<String, dynamic> json) {
    return HiWayNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      detail: json['detail'] as String,
      createdAtMs: (json['createdAtMs'] as num).toInt(),
      read: json['read'] as bool,
      urgent: json['urgent'] as bool,
    );
  }
}

class NotificationsStore {
  static const _itemsKey = 'hiway_notifications';

  static Future<List<HiWayNotification>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_itemsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    return decoded.map(HiWayNotification.fromJson).toList(growable: false);
  }

  static Future<void> add(HiWayNotification item) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await list();
    final next = [item, ...items];
    await prefs.setString(_itemsKey, jsonEncode(next.map((e) => e.toJson()).toList()));
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_itemsKey);
  }

  static Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    final items = await list();
    final next = items
        .map(
          (e) => HiWayNotification(
            id: e.id,
            title: e.title,
            subtitle: e.subtitle,
            detail: e.detail,
            createdAtMs: e.createdAtMs,
            read: true,
            urgent: e.urgent,
          ),
        )
        .toList(growable: false);
    await prefs.setString(_itemsKey, jsonEncode(next.map((e) => e.toJson()).toList()));
  }

  static Future<bool> hasUnread() async {
    final items = await list();
    return items.any((e) => !e.read);
  }
}

