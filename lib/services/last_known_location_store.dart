import 'package:shared_preferences/shared_preferences.dart';

class LastKnownLocationStore {
  static const _latKey = 'last_known_lat';
  static const _lngKey = 'last_known_lng';

  static Future<void> save({required double lat, required double lng}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, lat);
    await prefs.setDouble(_lngKey, lng);
  }

  static Future<(double, double)?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    if (lat == null || lng == null) {
      return null;
    }
    return (lat, lng);
  }
}

