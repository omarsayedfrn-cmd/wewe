import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

/// Service for profile CRUD operations.
class ProfileService {
  final SupabaseClient _client;

  ProfileService(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// Fetch the current user's profile (null if not yet created).
  Future<Profile?> getProfile() async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', _userId)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromJson(data);
  }

  /// Create a new profile during onboarding.
  Future<Profile> createProfile({
    required String grade,
    String? track,
    required String language,
    String? referredBy,
  }) async {
    final user = _client.auth.currentUser!;
    final fullName = user.userMetadata?['full_name'] as String? ?? '';
    final phone = user.userMetadata?['phone'] as String? ?? '';
    final displayName = fullName.isNotEmpty
        ? (phone.isNotEmpty ? '$fullName ($phone)' : fullName)
        : (phone.isNotEmpty ? phone : (user.email ?? ''));
    final avatar = user.userMetadata?['avatar_url'] as String?;

    // The RPC atomically upserts the profile, derives the allowed engines
    // server-side (bypassing the engine_access RLS safely) and is safe to retry.
    final data = await _client.rpc('complete_onboarding', params: {
      'p_grade': grade,
      'p_track': track,
      'p_language': language,
      'p_display_name': displayName,
      'p_avatar': avatar,
      'p_referred_by':
          (referredBy != null && referredBy.isNotEmpty) ? referredBy : null,
    });

    return Profile.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Update profile fields (only before onboarding is locked).
  Future<Profile> updateProfile(Map<String, dynamic> updates) async {
    final data = await _client
        .from('profiles')
        .update(updates)
        .eq('id', _userId)
        .select()
        .single();
    return Profile.fromJson(data);
  }
}
