import 'dart:convert';

import 'package:http/http.dart' as http;

class GooglePlacesDirectionsService {
  GooglePlacesDirectionsService({required this.apiKey});

  final String apiKey;

  Future<List<PlaceSuggestion>> autocomplete({
    required String input,
    required String sessionToken,
  }) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': input,
      'key': apiKey,
      'sessiontoken': sessionToken,
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status'] as String?;
    if (status != 'OK') {
      return [];
    }

    final predictions = (data['predictions'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return predictions
        .map(
          (p) => PlaceSuggestion(
            placeId: p['place_id'] as String,
            description: (p['description'] as String?) ?? '',
          ),
        )
        .toList(growable: false);
  }

  Future<PlaceDetails?> placeDetails({
    required String placeId,
    required String sessionToken,
  }) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'fields': 'geometry,name,formatted_address',
      'key': apiKey,
      'sessiontoken': sessionToken,
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status'] as String?;
    if (status != 'OK') {
      return null;
    }

    final result = data['result'] as Map<String, dynamic>;
    final geometry = result['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;

    return PlaceDetails(
      placeId: placeId,
      name: (result['name'] as String?) ?? '',
      formattedAddress: (result['formatted_address'] as String?) ?? '',
      lat: (location['lat'] as num).toDouble(),
      lng: (location['lng'] as num).toDouble(),
    );
  }

  Future<DirectionsResult?> directions({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    bool alternatives = false,
  }) async {
    final departureTime = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '$originLat,$originLng',
      'destination': '$destLat,$destLng',
      'mode': 'driving',
      'departure_time': departureTime.toString(),
      'traffic_model': 'best_guess',
      if (alternatives) 'alternatives': 'true',
      'key': apiKey,
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status'] as String?;
    if (status != 'OK') {
      return null;
    }

    final routes = (data['routes'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    if (routes.isEmpty) {
      return null;
    }

    Map<String, dynamic> bestRoute = routes.first;
    int? bestTrafficSeconds;
    for (final r in routes) {
      final legs = (r['legs'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
      if (legs.isEmpty) {
        continue;
      }
      final durationInTraffic = legs.first['duration_in_traffic'] as Map<String, dynamic>?;
      final duration = legs.first['duration'] as Map<String, dynamic>?;
      final trafficSeconds = (durationInTraffic?['value'] as num?)?.toInt() ??
          (duration?['value'] as num?)?.toInt();
      if (trafficSeconds == null) {
        continue;
      }
      if (bestTrafficSeconds == null || trafficSeconds < bestTrafficSeconds) {
        bestTrafficSeconds = trafficSeconds;
        bestRoute = r;
      }
    }

    final overviewPolyline = bestRoute['overview_polyline'] as Map<String, dynamic>;
    final points = overviewPolyline['points'] as String;
    final legs = (bestRoute['legs'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    final firstLeg = legs.isNotEmpty ? legs.first : null;

    String? distanceText;
    String? durationText;
    String? durationInTrafficText;
    int? durationSeconds;
    int? durationInTrafficSeconds;

    if (firstLeg != null) {
      final distance = firstLeg['distance'] as Map<String, dynamic>?;
      final duration = firstLeg['duration'] as Map<String, dynamic>?;
      final durationInTraffic = firstLeg['duration_in_traffic'] as Map<String, dynamic>?;

      distanceText = distance?['text'] as String?;
      durationText = duration?['text'] as String?;
      durationSeconds = (duration?['value'] as num?)?.toInt();
      durationInTrafficText = durationInTraffic?['text'] as String?;
      durationInTrafficSeconds = (durationInTraffic?['value'] as num?)?.toInt();
    }

    final steps = <DirectionsStep>[];
    if (firstLeg != null) {
      final rawSteps = (firstLeg['steps'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
      for (final s in rawSteps) {
        final instructionRaw = (s['html_instructions'] as String?) ?? '';
        final distance = s['distance'] as Map<String, dynamic>?;
        final duration = s['duration'] as Map<String, dynamic>?;
        final endLocation = s['end_location'] as Map<String, dynamic>?;

        final endLat = (endLocation?['lat'] as num?)?.toDouble();
        final endLng = (endLocation?['lng'] as num?)?.toDouble();
        if (endLat == null || endLng == null) {
          continue;
        }

        steps.add(
          DirectionsStep(
            instruction: _stripHtml(instructionRaw),
            distanceText: (distance?['text'] as String?) ?? '',
            durationText: (duration?['text'] as String?) ?? '',
            endLat: endLat,
            endLng: endLng,
          ),
        );
      }
    }

    return DirectionsResult(
      polylinePoints: decodePolyline(points),
      distanceText: distanceText,
      durationText: durationText,
      durationInTrafficText: durationInTrafficText,
      durationSeconds: durationSeconds,
      durationInTrafficSeconds: durationInTrafficSeconds,
      steps: steps,
    );
  }
}

class PlaceSuggestion {
  PlaceSuggestion({required this.placeId, required this.description});

  final String placeId;
  final String description;
}

class PlaceDetails {
  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
  });

  final String placeId;
  final String name;
  final String formattedAddress;
  final double lat;
  final double lng;
}

class DirectionsResult {
  DirectionsResult({
    required this.polylinePoints,
    required this.distanceText,
    required this.durationText,
    required this.durationInTrafficText,
    required this.durationSeconds,
    required this.durationInTrafficSeconds,
    required this.steps,
  });

  final List<List<double>> polylinePoints;
  final String? distanceText;
  final String? durationText;
  final String? durationInTrafficText;
  final int? durationSeconds;
  final int? durationInTrafficSeconds;
  final List<DirectionsStep> steps;
}

class DirectionsStep {
  DirectionsStep({
    required this.instruction,
    required this.distanceText,
    required this.durationText,
    required this.endLat,
    required this.endLng,
  });

  final String instruction;
  final String distanceText;
  final String durationText;
  final double endLat;
  final double endLng;
}

String _stripHtml(String input) {
  return input.replaceAll(RegExp('<[^>]*>'), '').trim();
}

List<List<double>> decodePolyline(String encoded) {
  final List<List<double>> points = [];

  int index = 0;
  int lat = 0;
  int lng = 0;

  while (index < encoded.length) {
    int shift = 0;
    int result = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    points.add([lat / 1e5, lng / 1e5]);
  }

  return points;
}
