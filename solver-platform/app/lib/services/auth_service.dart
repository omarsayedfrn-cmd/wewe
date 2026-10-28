import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';

/// Auth service wrapping Supabase Auth + Phone/Password + Google Sign-In.
class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Helper to convert a phone number into a deterministic internal email.
  static String phoneToEmail(String phone) {
    // Keep only numeric digits
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return 'user_$digits@solver.app';
  }

  /// Sign in with phone number & password.
  Future<AuthResponse> signInWithPhonePassword({
    required String phone,
    required String password,
  }) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.length < 8) {
      throw Exception('يرجى إدخال رقم هاتف صحيح');
    }
    if (password.length < 6) {
      throw Exception('كلمة المرور يجب أن لا تقل عن 6 أحرف');
    }

    final email = phoneToEmail(cleanPhone);
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up with phone number & password.
  Future<AuthResponse> signUpWithPhonePassword({
    required String phone,
    required String password,
    required String fullName,
  }) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.length < 8) {
      throw Exception('يرجى إدخال رقم هاتف صحيح');
    }
    if (password.length < 6) {
      throw Exception('كلمة المرور يجب أن لا تقل عن 6 أحرف');
    }
    if (fullName.trim().isEmpty) {
      throw Exception('يرجى إدخال اسم الطالب');
    }

    final email = phoneToEmail(cleanPhone);
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName.trim(),
        'phone': cleanPhone,
      },
    );

    if (res.user != null) {
      try {
        await _client.from('profiles').upsert({
          'id': res.user!.id,
          'role': 'student',
          'language': 'ar',
          'display_name': '${fullName.trim()} ($cleanPhone)',
          'onboard_locked': false,
        });
} catch (e) {
        debugPrint('[Auth] profile upsert after sign-up failed: $e');
      }
    }

    return res;
  }

  /// Sign in with Google (code preserved as requested).
  Future<AuthResponse> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      serverClientId: AppConstants.googleWebClientId,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('تم إلغاء تسجيل الدخول');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw Exception('تعذر الحصول على بيانات تسجيل الدخول من Google. حاول مرة أخرى.');
    }

    return await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  /// Sign out.
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      debugPrint('[Auth] Google sign-out failed: $e');
    }
    await _client.auth.signOut();
  }
}
