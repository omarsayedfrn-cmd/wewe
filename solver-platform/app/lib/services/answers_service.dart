import 'package:supabase_flutter/supabase_flutter.dart';

import '../solver/answers.dart';

/// Thrown when the server refuses or fails to provide the answer bank.
class AnswersUnavailableException implements Exception {
  final String message;
  const AnswersUnavailableException(this.message);

  @override
  String toString() => message;
}

/// Fetches the answer bank from the `solver-answers` Edge Function.
///
/// The answers are never shipped inside the APK. The server verifies the
/// caller's JWT, account approval, bound platform account, and entitlement
/// before returning anything, so the paywall can no longer be bypassed by
/// extracting assets from the app.
class AnswersService {
  final SupabaseClient _client;

  /// Per-engine cache for the current app session (avoids refetching when the
  /// user retries a solve).
  final Map<String, Map<String, dynamic>> _cache = {};

  AnswersService(this._client);

  Future<Map<String, dynamic>> _fetch(String engineCode) async {
    final cached = _cache[engineCode];
    if (cached != null) return cached;

    if (_client.auth.currentSession == null) {
      throw const AnswersUnavailableException('يجب تسجيل الدخول أولاً');
    }

    try {
      // The FunctionsClient attaches and refreshes the current JWT itself.
      final response = await _client.functions.invoke(
        'solver-answers',
        body: {'engine_code': engineCode},
      );

      final data = response.data;
      if (data is! Map) {
        throw const AnswersUnavailableException('استجابة غير صالحة من السيرفر');
      }

      final answers = data['answers'];
      if (answers is! Map) {
        final code = data['error']?.toString();
        throw AnswersUnavailableException(_messageForCode(code));
      }

      final map = Map<String, dynamic>.from(answers);
      _cache[engineCode] = map;
      return map;
    } on FunctionException catch (e) {
      throw AnswersUnavailableException(_messageForException(e));
    }
  }

  String _messageForException(FunctionException e) {
    final details = e.details;
    if (details is Map) {
      return _messageForCode(details['error']?.toString());
    }
    return 'تعذر تحميل إجابات هذه المنصة (HTTP ${e.status})';
  }

  String _messageForCode(String? code) {
    switch (code) {
      case 'account_pending_approval':
        return 'حسابك قيد المراجعة. سيتم تفعيله بعد موافقة الإدارة.';
      case 'no_entitlement':
        return 'هذه المنصة غير مفتوحة لحسابك الحالي.';
      case 'no_entitled_chapters':
        return 'لا يوجد فصول مفتوحة لهذا الحساب في هذه المنصة.';
      case 'answers_unavailable':
        return 'إجابات هذه المنصة غير متاحة حالياً. تواصل مع الدعم.';
      case 'unauthorized':
      case 'profile_not_found':
        return 'انتهت الجلسة أو الحساب غير صالح. سجّل الدخول من جديد.';
      case 'unknown_engine':
        return 'منصة غير معروفة.';
      default:
        return 'تعذر تحميل إجابات هذه المنصة'
            '${code != null ? ' ($code)' : ''}.';
    }
  }

  /// QUREO answers: raw chapter id -> QChapter.
  Future<Map<String, QChapter>> getQureo(String engineCode) async {
    final raw = await _fetch(engineCode);
    final result = <String, QChapter>{};

    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is Map) {
        result[entry.key] =
            QChapter.fromJson(Map<String, dynamic>.from(value));
      }
    }

    return result;
  }

  /// SPRIX chapters: chapterId -> list of (blockId, optionId).
  Future<Map<String, List<IdPair>>> getSprixChapters(String engineCode) async {
    final raw = await _fetch(engineCode);
    return _pairs(raw['chapters']);
  }

  /// SPRIX tests: testId -> list of (questionId, optionId).
  Future<Map<String, List<IdPair>>> getSprixTests(String engineCode) async {
    final raw = await _fetch(engineCode);
    return _pairs(raw['tests']);
  }

  Map<String, List<IdPair>> _pairs(dynamic source) {
    if (source is! Map) return {};

    final result = <String, List<IdPair>>{};
    for (final entry in source.entries) {
      final list = entry.value;
      if (list is! List) continue;
      result[entry.key.toString()] = list.map((item) {
        final pair = item as List<dynamic>;
        return (pair[0] as int, pair[1] as int);
      }).toList();
    }
    return result;
  }

  /// Clears the cached answers (e.g. after a purchase or account change).
  void clearCache() => _cache.clear();
}