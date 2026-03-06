import 'package:flutter/services.dart';

class ApiKeys {
  static const MethodChannel _channel = MethodChannel('hiway/keys');

  static Future<String?> googleMapsWebApiKey() async {
    final value = await _channel.invokeMethod<String>('googleMapsWebApiKey');
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}

