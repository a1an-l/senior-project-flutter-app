// lib/services/route_service.dart

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/route_model.dart';

class RouteService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> saveNewRoute(List<LatLng> finalTrackedPoints, int currentUserId) async {
    if (finalTrackedPoints.isEmpty || finalTrackedPoints.length < 2) {
      print('Route Service: Not enough points to save a route.');
      return;
    }

    // Create the model
    final newRoute = RouteModel(
      userId: currentUserId, // Passing the int ID from your users table
      routePoints: finalTrackedPoints,
    );

    try {
      // Insert into the new RouteDB table
      await _supabase
          .from('routedb')
          .insert(newRoute.toJson());

      print('Route Service: Route successfully saved to routedb!');
    } catch (error) {
      print('Route Service: Error saving route: $error');
      rethrow;
    }
  }
}