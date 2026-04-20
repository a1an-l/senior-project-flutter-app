import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> updateProfile({
    required int userId,
    required String username,
    required String email,
  }) async {
    await _client.from('users').update({
      'username': username,
      'email': email,
    }).eq('user_id', userId);
  }

  /// Uploads image to Supabase Storage and saves the URL into the photo JSONB column.
Future<String> updateProfilePhoto({
  required int userId,
  required File imageFile,
}) async {
  final ext = imageFile.path.split('.').last;
  final filePath = 'avatars/avatar_$userId.$ext';

  print('auth user: ${_client.auth.currentUser?.id}');
  print('auth email: ${_client.auth.currentUser?.email}');
  print('session exists: ${_client.auth.currentSession != null}');
  print('upload path: $filePath');

  await _client.storage.from('profile-photos').upload(
        filePath,
        imageFile,
        fileOptions: const FileOptions(upsert: true),
      );

  final publicUrl =
      _client.storage.from('profile-photos').getPublicUrl(filePath);

  await _client.from('users').update({
    'photo': {
      'url': publicUrl,
      'updated_at': DateTime.now().toIso8601String(),
    },
  }).eq('user_id', userId);

  return publicUrl;
}
  /// for password resets
  Future<void> sendPasswordResetEmail(String email) async {
  await _client.auth.resetPasswordForEmail(
    email,
    redirectTo: 'hiway://reset-callback',
  );
}

  /// Fetches the current user's photo URL from the JSONB column.
  Future<String?> getProfilePhotoUrl(int userId) async {
    final response = await _client
        .from('users')
        .select('photo')
        .eq('user_id', userId)
        .maybeSingle();

    final photo = response?['photo'];
    if (photo is Map) return photo['url'] as String?;
    return null;
  }
}