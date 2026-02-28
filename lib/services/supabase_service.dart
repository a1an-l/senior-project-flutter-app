import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  SupabaseClient get client {
    try {
      return Supabase.instance.client;
    } catch (e) {
      throw Exception('Supabase not initialized: $e');
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      // Sign up with Supabase Auth
      await client.auth.signUp(
        email: email,
        password: password,
      );

      // Insert user profile with username into your users table
      await client.from('users').insert({
        'email': email,
        'username': username,
        'password': password,
        'created_at': DateTime.now().toIso8601String()
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> getCurrentUserId() async {
    try {
      return client.auth.currentUser?.id;
    } catch (e) {
      return null;
    }
  }
}
