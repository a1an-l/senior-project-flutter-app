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
  });

  final String label;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String placeId;

  Map<String, dynamic> toJson() => {
        'label': label,
        'name': name,
        'address': address,
        'lat': lat,
        'lng': lng,
        'placeId': placeId,
      };

  static SavedPlace fromJson(Map<String, dynamic> json) {
    return SavedPlace(
      label: json['label'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      placeId: json['placeId'] as String,
    );
  }
}

class SavedPlacesStore {
  static String _keyForLabel(String label) => 'saved_place_${label.toLowerCase()}';

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
  }
}

