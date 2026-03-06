import 'package:flutter/services.dart';

class ApiKeys {
  static const MethodChannel _channel = MethodChannel('hiway/keys');

  static Future<String?> mapsApiKey() async {
    final value = await _channel.invokeMethod<String>('mapsApiKey');
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}
