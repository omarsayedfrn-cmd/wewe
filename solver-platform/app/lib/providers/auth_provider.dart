import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

/// Supabase client provider.
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Auth service provider.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseProvider));
});

/// Profile service provider.
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.watch(supabaseProvider));
});

/// Auth state provider — streams auth changes.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Current user provider — derives from the auth stream so it updates
/// immediately on sign-in/sign-out without requiring an app restart.
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (state) => state.session?.user,
    orElse: () => ref.watch(supabaseProvider).auth.currentUser,
  );
});

/// Profile provider — fetches and caches the user's profile.
final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, Profile?>(ProfileNotifier.new);

class ProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    // Wait for Supabase to settle its session before deciding that the user
    // has no profile. During the very first frames authStateProvider is still
    // loading; returning null there made returning users see onboarding again.
    final authUserId = ref.watch(authStateProvider.select(
      (auth) => auth.valueOrNull?.session?.user.id,
    ));
    final clientUserId = ref.read(supabaseProvider).auth.currentUser?.id;
    final userId = authUserId ?? clientUserId;

    if (userId == null) {
      if (ref.read(authStateProvider).isLoading) {
        // Keep the profile in a loading state until auth resolves.
        return Completer<Profile?>().future;
      }
      return null;
    }

    return ref.read(profileServiceProvider).getProfile();
  }

  /// Refresh profile from DB.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(profileServiceProvider).getProfile());
  }

  /// Create profile during onboarding.
  Future<Profile> createProfile({
    required String grade,
    String? track,
    required String language,
    String? referredBy,
  }) async {
    // Never re-run onboarding for an already locked profile (this used to
    // overwrite grade/track/language when the screen was shown by mistake).
    final existing = state.valueOrNull;
    if (existing != null && existing.onboardLocked) return existing;

    final profile = await ref.read(profileServiceProvider).createProfile(
          grade: grade,
          track: track,
          language: language,
          referredBy: referredBy,
        );
    state = AsyncData(profile);
    return profile;
  }

  /// Bind the platform account (student login code) to the profile.
  Future<Profile> bindPlatformAccount(String login) async {
    final profile =
        await ref.read(profileServiceProvider).bindPlatformAccount(login);
    state = AsyncData(profile);
    return profile;
  }

  /// Remove the bound platform account.
  Future<Profile> unbindPlatformAccount() async {
    final profile =
        await ref.read(profileServiceProvider).unbindPlatformAccount();
    state = AsyncData(profile);
    return profile;
  }
}
