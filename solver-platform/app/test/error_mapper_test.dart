import 'package:flutter_test/flutter_test.dart';
import 'package:solver_app/core/app_error.dart';
import 'package:solver_app/solver/api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('describeError', () {
    test('maps invalid login credentials', () {
      final info = describeError(AuthException('Invalid login credentials'));
      expect(info.title, 'بيانات الدخول غير صحيحة');
      expect(info.details, isNotNull);
    });

    test('maps an already registered phone', () {
      final info = describeError(AuthException('User already registered'));
      expect(info.title, 'الرقم مسجل مسبقًا');
    });

    test('maps insufficient wallet balance', () {
      final info = describeError(
        const PostgrestException(
          message: 'Insufficient balance: have 5, need 100',
          code: 'P0001',
        ),
      );
      expect(info.title, 'الرصيد غير كافٍ');
    });

    test('maps a locked/forbidden solver response', () {
      final info = describeError(const SolverStop('login: HTTP 401 <html>'));
      expect(info.title, 'تعذر تسجيل الدخول للمنصة');
    });

    test('maps solver rate limiting', () {
      final info = describeError(const SolverStop('GET x: HTTP 429'));
      expect(info.title, 'محاولات كثيرة');
    });

    test('maps an unsupported engine', () {
      final info = describeError(const SolverStop('محرك غير مدعوم: foo'));
      expect(info.title, 'المحرك غير مدعوم');
    });

    test('keeps an Arabic service message intact', () {
      final info = describeError(Exception('هذا الرقم مسجل مسبقاً'));
      expect(info.message, 'هذا الرقم مسجل مسبقاً');
      expect(info.title, 'تعذر إتمام العملية');
    });

    test('falls back to a generic hidden-details error', () {
      final info = describeError(StateError('boom'));
      expect(info.title, 'حدث خطأ غير متوقع');
      expect(info.details, contains('boom'));
    });
  });

  test('detects a missing backend migration', () {
    expect(
      isMissingBackendFeature(
        const PostgrestException(
          message: 'Could not find the function public.claim_trial',
          code: 'PGRST202',
        ),
      ),
      isTrue,
    );
    expect(isMissingBackendFeature(AuthException('nope')), isFalse);
  });
}