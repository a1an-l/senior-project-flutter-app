import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseNotificationsService {
  static final SupabaseNotificationsService _instance =
      SupabaseNotificationsService._internal();

  factory SupabaseNotificationsService() {
    return _instance;
  }

  SupabaseNotificationsService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Saves a notification to Supabase 'alerts' table
  Future<void> saveNotification({
    required String title,
    required String subtitle,
    required String detail,
    required int createdAtMs,
  }) async {
    try {
      // Get the user ID from local storage
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');

      if (userId == null) {
        print('SupabaseNotificationsService: No user ID found, skipping database save');
        return;
      }

      // Convert milliseconds to ISO8601 timestamp
      final timestamp =
          DateTime.fromMillisecondsSinceEpoch(createdAtMs).toUtc().toIso8601String();

      // Combine title, subtitle, and detail into alert message
      final alertMsg = '$title - $subtitle: $detail';

      // Insert into alerts table
      await _supabase.from('alerts').insert({
        'timestamp': timestamp,
        'alert_msg': alertMsg,
        'user_id': userId,
      });

      print('SupabaseNotificationsService: Alert saved successfully');
    } catch (e) {
      print('SupabaseNotificationsService: Error saving alert: $e');
      // Don't rethrow - we want to continue even if Supabase save fails
    }
  }

  /// Fetches all alerts for the current user
  Future<List<Map<String, dynamic>>> getUserAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');

      if (userId == null) {
        print('SupabaseNotificationsService: No user ID found');
        return [];
      }

      final response = await _supabase
          .from('alerts')
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false);

      return response as List<Map<String, dynamic>>;
    } catch (e) {
      print('SupabaseNotificationsService: Error fetching alerts: $e');
      return [];
    }
  }

  /// Deletes all alerts for the current user
  Future<void> clearAllAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('user_id');

      if (userId == null) {
        return;
      }

      await _supabase
          .from('alerts')
          .delete()
          .eq('user_id', userId);

      print('SupabaseNotificationsService: All alerts cleared');
    } catch (e) {
      print('SupabaseNotificationsService: Error clearing alerts: $e');
    }
  }
}
