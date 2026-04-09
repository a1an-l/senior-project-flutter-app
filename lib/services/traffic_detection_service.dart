import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../config/api_config.dart';

enum TrafficCondition { freeFlow, congested, serious }

class TrafficData {
  final TrafficCondition condition;
  final double durationInTraffic; // in minutes
  final double durationWithoutTraffic; // in minutes
  final String direction; // N, S, E, W

  TrafficData({
    required this.condition,
    required this.durationInTraffic,
    required this.durationWithoutTraffic,
    required this.direction,
  });

  double get delayMinutes => durationInTraffic - durationWithoutTraffic;
}

class TrafficDetectionService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  // Calculate destination point at given distance and bearing from origin
  static Position _calculateDestination(Position origin, double distanceMiles, double bearingDegrees) {
    const double earthRadiusMiles = 3959; // Earth's radius in miles
    final double bearingRadians = bearingDegrees * (3.141592653589793 / 180);
    final double distanceRadians = distanceMiles / earthRadiusMiles;

    final double originLatRadians = origin.latitude * (3.141592653589793 / 180);
    final double originLngRadians = origin.longitude * (3.141592653589793 / 180);

    final double destLatRadians = asin(
      sin(originLatRadians) * cos(distanceRadians) +
      cos(originLatRadians) * sin(distanceRadians) * cos(bearingRadians)
    );

    final double destLngRadians = originLngRadians + atan2(
      sin(bearingRadians) * sin(distanceRadians) * cos(originLatRadians),
      cos(distanceRadians) - sin(originLatRadians) * sin(destLatRadians)
    );

    return Position(
      latitude: destLatRadians * (180 / 3.141592653589793),
      longitude: destLngRadians * (180 / 3.141592653589793),
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  // Get traffic data for a specific direction
  static Future<TrafficData?> _getTrafficForDirection(
    Position origin,
    double distanceMiles,
    double bearingDegrees,
    String direction
  ) async {
    try {
      final destination = _calculateDestination(origin, distanceMiles, bearingDegrees);
      print('[TrafficAPI] Checking $direction direction - dest: ${destination.latitude}, ${destination.longitude}');

      final url = Uri.parse(
        '$_baseUrl?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&departure_time=now'
        '&traffic_model=$trafficModel'
        '&key=$googleMapsApiKey'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          final durationInTraffic = leg['duration_in_traffic']['value'] / 60; // Convert to minutes
          final durationWithoutTraffic = leg['duration']['value'] / 60; // Convert to minutes

          TrafficCondition condition;
          final delay = durationInTraffic - durationWithoutTraffic;

          if (delay < 2) {
            condition = TrafficCondition.freeFlow;
          } else if (delay < 5) {
            condition = TrafficCondition.congested;
          } else {
            condition = TrafficCondition.serious;
          }

          print('[TrafficAPI] $direction: $condition (delay: ${delay.round()}min)');

          return TrafficData(
            condition: condition,
            durationInTraffic: durationInTraffic,
            durationWithoutTraffic: durationWithoutTraffic,
            direction: direction,
          );
        }
      }
    } catch (e) {
      print('[TrafficAPI] Error getting traffic for direction $direction: $e');
    }
    return null;
  }

  // Get traffic data for all four directions
  static Future<List<TrafficData>> getTrafficAroundLocation(
    Position userLocation,
    double radiusMiles
  ) async {
    final List<Future<TrafficData?>> futures = [
      _getTrafficForDirection(userLocation, radiusMiles, 0, 'N'),   // North
      _getTrafficForDirection(userLocation, radiusMiles, 90, 'E'),  // East
      _getTrafficForDirection(userLocation, radiusMiles, 180, 'S'), // South
      _getTrafficForDirection(userLocation, radiusMiles, 270, 'W'), // West
    ];

    final results = await Future.wait(futures);
    return results.where((data) => data != null).cast<TrafficData>().toList();
  }

  // Check if there's serious traffic nearby
  static Future<bool> hasSeriousTraffic(Position userLocation, double radiusMiles) async {
    final trafficData = await getTrafficAroundLocation(userLocation, radiusMiles);
    return trafficData.any((data) => data.condition == TrafficCondition.serious);
  }

  // Get the worst traffic condition
  static Future<TrafficCondition> getWorstTrafficCondition(Position userLocation, double radiusMiles) async {
    final trafficData = await getTrafficAroundLocation(userLocation, radiusMiles);

    if (trafficData.isEmpty) return TrafficCondition.freeFlow;

    TrafficCondition worst = TrafficCondition.freeFlow;
    for (final data in trafficData) {
      if (data.condition.index > worst.index) {
        worst = data.condition;
      }
    }
    return worst;
  }
}

