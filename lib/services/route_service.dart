// lib/services/route_service.dart

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/route_model.dart';

class RouteService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> saveNewRoute(List<LatLng> finalTrackedPoints, int currentUserId, String routeName, List<Map<String, dynamic>> pendingAlarms) async {
    if (finalTrackedPoints.isEmpty || finalTrackedPoints.length < 2) {
      print('Route Service: Not enough points to save a route.');
      return;
    }

    final newRoute = RouteModel(
      userId: currentUserId,
      routePoints: finalTrackedPoints,
    );

    try {
      final Map<String, dynamic> insertData = newRoute.toJson();
      insertData['route_name'] = routeName;

      // 1. Insert the route and return the newly generated route_id
      final response = await _supabase
          .from('routedb')
          .insert(insertData)
          .select('route_id')
          .single();

      final targetRouteId = response['route_id'];

      // 2. Insert any alarms tied to this newly generated route
      if (pendingAlarms.isNotEmpty) {
        final alarmsToInsert = pendingAlarms.map((alarm) => {
          'route_id': targetRouteId,
          'start_time': alarm['start_time'],
          'end_time': alarm['end_time'],
          'days_repeating': alarm['days_repeating']
        }).toList();

        await _supabase.from('time').insert(alarmsToInsert);
      }

      print('Route Service: Route "$routeName" and alarms successfully saved!');
    } catch (error) {
      print('Route Service: Error saving route: $error');
      rethrow;
    }
  }
}