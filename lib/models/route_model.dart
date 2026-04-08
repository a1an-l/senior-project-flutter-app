// lib/models/route_model.dart

import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteModel {
  final int? routeId;
  final int userId; // Changed to int to match your bigint user_id
  final List<LatLng> routePoints;
  final String? routeName;
  final double? distanceMeters;

  RouteModel({
    this.routeId,
    required this.userId,
    required this.routePoints,
    this.routeName,
    this.distanceMeters,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['route_points'] as List<dynamic>;

    List<LatLng> capturedPoints = rawPoints.map((dynamic point) {
      final pointList = point as List<dynamic>;
      return LatLng(pointList[0] as double, pointList[1] as double);
    }).toList();

    return RouteModel(
      routeId: json['route_id'],
      userId: json['user_id'],
      routePoints: capturedPoints,
      routeName: json['route_name'],
      distanceMeters: json['distance_meters']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    final jsonPoints = routePoints.map((LatLng point) => [point.latitude, point.longitude]).toList();

    return {
      'user_id': userId,
      'route_points': jsonPoints,
      'route_name': routeName ?? 'My Tracked Route',
      'distance_meters': distanceMeters,
    };
  }
}