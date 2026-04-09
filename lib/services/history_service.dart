import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Saves a newly navigated route to the historydb table
  Future<void> saveToHistory({
    required int userId,
    required String startAddress,
    required String destinationAddress,
  }) async {
    try {
      // Matches the exact column names from your teacher's schema
      await _supabase.from('historydb').insert({
        'user_id': userId,
        'dst_address': destinationAddress,
        'Start_add': startAddress,
      });

      print('History Service: Successfully saved to historydb!');
    } catch (e) {
      print('History Service: Error saving to history: $e');
      rethrow;
    }
  }

  /// Fetches the user's history from newest to oldest
  Future<List<Map<String, dynamic>>> getUserHistory(int userId) async {
    try {
      final response = await _supabase
          .from('historydb')
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false); // Puts the newest trips at the top

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('History Service: Error fetching history: $e');
      return [];
    }
  }
}