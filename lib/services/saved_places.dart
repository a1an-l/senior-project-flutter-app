import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedPlace {
  const SavedPlace({
    required this.label,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.placeId,
    required this.avgSeconds,
    required this.samples,
  });

  final String label;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String placeId;
  final int? avgSeconds;
  final int? samples;

  Map<String, dynamic> toJson() => {
        'label': label,
        'name': name,
        'address': address,
        'lat': lat,
        'lng': lng,
        'placeId': placeId,
        'avgSeconds': avgSeconds,
        'samples': samples,
      };

  static SavedPlace fromJson(Map<String, dynamic> json) {
    final legacyNormal = (json['normalSeconds'] as num?)?.toInt();
    final avg = (json['avgSeconds'] as num?)?.toInt() ?? legacyNormal;
    final samples = (json['samples'] as num?)?.toInt() ?? (legacyNormal == null ? null : 1);
    return SavedPlace(
      label: json['label'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      placeId: json['placeId'] as String,
      avgSeconds: avg,
      samples: samples,
    );
  }
}

class SavedPlacesStore {
  static String _keyForLabel(String label) => 'saved_place_${label.toLowerCase()}';
  static const _labelsKey = 'saved_place_labels';

  static Future<SavedPlace?> get(String label) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyForLabel(label));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return SavedPlace.fromJson(decoded);
  }

  static Future<void> set(SavedPlace place) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyForLabel(place.label), jsonEncode(place.toJson()));

    final labels = prefs.getStringList(_labelsKey) ?? [];
    if (!labels.contains(place.label)) {
      await prefs.setStringList(_labelsKey, [...labels, place.label]);
    }
  }

  static Future<List<String>> labels() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_labelsKey) ?? [];
  }
}
