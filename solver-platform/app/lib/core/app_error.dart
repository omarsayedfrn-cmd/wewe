import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../solver/api.dart';

/// A user-facing description of an error plus the raw technical details.
///
/// The app shows [title], [message] and [hint] to the student in Arabic, while
/// [details] stays hidden behind a "التفاصيل التقنية" button so the developer
/// or support team can diagnose the real cause without exposing it to users.
class AppError {
  final String title;
  final String message;
  final String? hint;
  final String? details;

  const AppError({
    required this.title,
    required this.message,
    this.hint,
    this.details,
  });

  /// Short text suitable for a SnackBar.
  String get summary => hint == null ? message : '$message $hint';
}

/// Convert any caught object into a friendly [AppError].
///
/// [action] is only used for the developer log (e.g. "تسجيل الدخول").
AppError describeError(Object error, {String? action}) {
  final details = _rawDetails(error);
  debugPrint('[AppError]${action == null ? '' : ' [$action]'} $details');

  if (error is AppError) return error;
  if (error is SolverStop) return _solver(error.message, details);
  if (error is DioException) return _dio(error, details);
  if (error is AuthException) return _auth(error.message, details);
  if (error is PostgrestException) return _postgrest(error, details);
  if (error is SocketException) return _withDetails(_network, details);
  if (error is TimeoutException) return _withDetails(_timeout, details);
  if (error is HandshakeException) return _withDetails(_secureConnection, details);
  if (error is PlatformException) return _platform(error, details);
  if (error is FormatException || error is TypeError) {
    return _withDetails(_badData, details);
  }

  final text = _clean(error);
  final lower = text.toLowerCase();

  if (lower.contains('not authenticated') ||
      lower.contains('jwt expired') ||
      lower.contains('invalid jwt')) {
    return _withDetails(_sessionExpired, details);
  }
  if (lower.contains('socket') ||
      lower.contains('network') ||
      lower.contains('connection')) {
    return _withDetails(_network, details);
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return _withDetails(_timeout, details);
  }

  // Our own services already throw readable Arabic messages.
  if (_hasArabic(text)) {
    return AppError(
      title: 'تعذر إتمام العملية',
      message: text,
      details: details,
    );
  }

  return _withDetails(_generic, details);
}

// ── Base messages ────────────────────────────────────────────────────────────

const _network = AppError(
  title: 'لا يوجد اتصال بالإنترنت',
  message: 'تحقق من اتصالك بالإنترنت ثم حاول مرة أخرى.',
);

const _timeout = AppError(
  title: 'انتهت مهلة الاتصال',
  message: 'استغرق الخادم وقتًا طويلًا للرد. يرجى المحاولة مرة أخرى.',
);

const _secureConnection = AppError(
  title: 'تعذر إنشاء اتصال آمن',
  message: 'تحقق من إعدادات الشبكة أو التاريخ والوقت على جهازك ثم حاول مرة أخرى.',
);

const _server = AppError(
  title: 'الخادم غير متاح',
  message: 'تعذر الاتصال بالخادم حاليًا. حاول بعد قليل.',
  hint: 'إذا استمرت المشكلة، تواصل مع الدعم الفني.',
);

const _badData = AppError(
  title: 'بيانات غير صالحة',
  message: 'وصلت بيانات غير متوقعة من الخادم. حاول مرة أخرى.',
);

const _generic = AppError(
  title: 'حدث خطأ غير متوقع',
  message: 'لم نتمكن من إتمام العملية. يرجى المحاولة مرة أخرى.',
  hint: 'إذا استمرت المشكلة، تواصل مع الدعم الفني.',
);

const _sessionExpired = AppError(
  title: 'انتهت الجلسة',
  message: 'يرجى تسجيل الدخول مرة أخرى للمتابعة.',
);

const _permission = AppError(
  title: 'ليس لديك صلاحية',
  message: 'لا تملك صلاحية تنفيذ هذه العملية.',
  hint: 'تأكد من تسجيل الدخول الصحيح أو تواصل مع الدعم الفني.',
);

const _duplicate = AppError(
  title: 'البيانات مسجلة مسبقًا',
  message: 'هذه البيانات موجودة بالفعل، لا حاجة لتكرارها.',
);

const _notFound = AppError(
  title: 'البيانات غير موجودة',
  message: 'لم نتمكن من العثور على البيانات المطلوبة.',
  hint: 'حدّث الصفحة أو حاول مرة أخرى.',
);

const _invalidData = AppError(
  title: 'بيانات غير مكتملة',
  message: 'بعض البيانات المطلوبة غير صحيحة. راجع اختياراتك وحاول مرة أخرى.',
);

const _missingFeature = AppError(
  title: 'الميزة غير مفعّلة',
  message: 'هذه الميزة غير متاحة على الخادم حاليًا.',
  hint: 'تواصل مع الدعم الفني لتفعيلها.',
);

const _loginFailed = AppError(
  title: 'بيانات الدخول غير صحيحة',
  message: 'رقم الهاتف أو كلمة المرور غير صحيحة.',
  hint: 'تأكد من البيانات، أو تواصل مع الإدارة لتفعيل حسابك.',
);

const _alreadyRegistered = AppError(
  title: 'الرقم مسجل مسبقًا',
  message: 'هذا الرقم مسجل بالفعل.',
  hint: 'استخدم «تسجيل الدخول» بدلًا من إنشاء حساب جديد.',
);

const _accountNotActive = AppError(
  title: 'الحساب غير مفعّل',
  message: 'حسابك يحتاج إلى تأكيد أو تفعيل قبل تسجيل الدخول.',
  hint: 'تواصل مع الإدارة لتفعيل الحساب.',
);

const _rateLimited = AppError(
  title: 'محاولات كثيرة',
  message: 'تمت محاولات كثيرة خلال وقت قصير.',
  hint: 'انتظر قليلًا ثم حاول مرة أخرى.',
);

const _signupDisabled = AppError(
  title: 'التسجيل غير متاح',
  message: 'إنشاء حسابات جديدة غير متاح حاليًا.',
  hint: 'تواصل مع الدعم الفني.',
);

const _insufficientBalance = AppError(
  title: 'الرصيد غير كافٍ',
  message: 'رصيد محفظتك لا يكفي لإتمام هذه العملية.',
  hint: 'اشحن المحفظة عبر التواصل مع الدعم الفني.',
);

const _walletMissing = AppError(
  title: 'تعذر الوصول للمحفظة',
  message: 'لم يتم العثور على محفظة لحسابك.',
  hint: 'تواصل مع الدعم الفني لإنشائها.',
);

const _pricingMissing = AppError(
  title: 'السعر غير متاح',
  message: 'لم يتم إعداد سعر هذه المنصة بعد.',
  hint: 'تواصل مع الإدارة.',
);

const _fullOnly = AppError(
  title: 'شراء الفصول غير متاح',
  message: 'يمكنك فقط فتح المنصة كاملة.',
  hint: 'اختر «فتح المنصة كاملة» لإتمام الشراء.',
);

const _trialDisabled = AppError(
  title: 'التجربة المجانية غير متاحة',
  message: 'التجربة المجانية غير مفعّلة حاليًا.',
  hint: 'يمكنك فتح المنصة كاملة للمتابعة.',
);

const _trialUsed = AppError(
  title: 'تم استخدام التجربة المجانية',
  message: 'لقد استخدمت تجربتك المجانية بالفعل.',
  hint: 'افتح المنصة كاملة للمتابعة.',
);

const _trialNotReady = AppError(
  title: 'أكمل إعداد حسابك',
  message: 'يجب إكمال إعداد الحساب أولًا قبل بدء التجربة.',
);

const _cancelled = AppError(
  title: 'تم الإلغاء',
  message: 'تم إلغاء العملية.',
);

// ── Mappers ──────────────────────────────────────────────────────────────────

AppError _auth(String raw, String details) {
  final m = raw.toLowerCase();
  if (m.contains('invalid login credentials') ||
      m.contains('invalid credentials')) {
    return _withDetails(_loginFailed, details);
  }
  if (m.contains('user already registered') || m.contains('already registered')) {
    return _withDetails(_alreadyRegistered, details);
  }
  if (m.contains('email not confirmed') || m.contains('not confirmed')) {
    return _withDetails(_accountNotActive, details);
  }
  if (m.contains('password') && m.contains('at least')) {
    return _withDetails(
      const AppError(
        title: 'كلمة المرور ضعيفة',
        message: 'كلمة المرور قصيرة جدًا.',
        hint: 'استخدم 6 أحرف على الأقل.',
      ),
      details,
    );
  }
  if (m.contains('rate limit') || m.contains('too many')) {
    return _withDetails(_rateLimited, details);
  }
  if (m.contains('signup') && m.contains('disabled')) {
    return _withDetails(_signupDisabled, details);
  }
  if (m.contains('session') &&
      (m.contains('expired') || m.contains('missing') || m.contains('invalid'))) {
    return _withDetails(_sessionExpired, details);
  }
  if (m.contains('user not found')) {
    return _withDetails(_loginFailed, details);
  }
  if (m.contains('network') ||
      m.contains('connection') ||
      m.contains('socket')) {
    return _withDetails(_network, details);
  }
  return _withDetails(_generic, details);
}

AppError _postgrest(PostgrestException error, String details) {
  final m = '${error.message} ${error.details ?? ''}'.toLowerCase();
  final code = error.code ?? '';

  if (code == '42501' ||
      m.contains('row-level security') ||
      m.contains('permission denied') ||
      m.contains('insufficient privilege')) {
    return _withDetails(_permission, details);
  }
  if (code == '23505' || m.contains('duplicate key')) {
    return _withDetails(_duplicate, details);
  }
  if (code == 'PGRST116' || m.contains('no rows')) {
    return _withDetails(_notFound, details);
  }
  if (code == 'PGRST202' ||
      m.contains('could not find the function') ||
      m.contains('schema cache')) {
    return _withDetails(_missingFeature, details);
  }
  if (m.contains('insufficient balance')) {
    return _withDetails(_insufficientBalance, details);
  }
  if (m.contains('wallet not found')) {
    return _withDetails(_walletMissing, details);
  }
  if (m.contains('no pricing found')) {
    return _withDetails(_pricingMissing, details);
  }
  if (m.contains('only full-engine purchases')) {
    return _withDetails(_fullOnly, details);
  }
  if (m.contains('trial is disabled')) {
    return _withDetails(_trialDisabled, details);
  }
  if (m.contains('trial already used')) {
    return _withDetails(_trialUsed, details);
  }
  if (m.contains('profile is not ready')) {
    return _withDetails(_trialNotReady, details);
  }
  if (m.contains('not authenticated') ||
      m.contains('jwt expired') ||
      m.contains('invalid jwt')) {
    return _withDetails(_sessionExpired, details);
  }
  if (m.contains('invalid grade') ||
      m.contains('invalid language') ||
      m.contains('invalid track') ||
      m.contains('invalid scope')) {
    return _withDetails(_invalidData, details);
  }
  if (m.contains('invalid login credentials')) {
    return _withDetails(_loginFailed, details);
  }
  if (m.contains('timeout') ||
      m.contains('connection') ||
      m.contains('network')) {
    return _withDetails(_network, details);
  }
  return _withDetails(_generic, details);
}

AppError _dio(DioException error, String details) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return _withDetails(_timeout, details);
    case DioExceptionType.connectionError:
      return _withDetails(_network, details);
    case DioExceptionType.badCertificate:
      return _withDetails(_secureConnection, details);
    case DioExceptionType.cancel:
      return _withDetails(_cancelled, details);
    case DioExceptionType.badResponse:
      final status = error.response?.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return _withDetails(
          const AppError(
            title: 'تم رفض الطلب',
            message: 'الخادم رفض الوصول إلى هذه البيانات.',
            hint: 'تأكد من بيانات الدخول أو تواصل مع الدعم.',
          ),
          details,
        );
      }
      if (status == 404) return _withDetails(_notFound, details);
      if (status == 429) return _withDetails(_rateLimited, details);
      return _withDetails(_server, details);
    case DioExceptionType.unknown:
      if (error.error is SocketException) return _withDetails(_network, details);
      if (error.error is HandshakeException) {
        return _withDetails(_secureConnection, details);
      }
      return _withDetails(_generic, details);
  }
}

AppError _platform(PlatformException error, String details) {
  final code = error.code.toLowerCase();
  if (code.contains('cancel')) return _withDetails(_cancelled, details);
  if (code.contains('network') || code.contains('connection')) {
    return _withDetails(_network, details);
  }
  return _withDetails(_generic, details);
}

AppError _solver(String raw, String details) {
  final lower = raw.toLowerCase();
  final statusMatch = RegExp(r'http\s+(\d{3})').firstMatch(lower);
  final status = statusMatch == null ? null : int.tryParse(statusMatch.group(1)!);

  if (status == 401 || status == 403 || lower.contains('locked/forbidden')) {
    return _withDetails(
      const AppError(
        title: 'تعذر تسجيل الدخول للمنصة',
        message: 'كود الطالب أو كلمة المرور غير صحيحة، أو الحساب غير مفعّل على المنصة.',
        hint: 'راجع بيانات الدخول الخاصة بالمنصة من المدرسة ثم حاول مرة أخرى.',
      ),
      details,
    );
  }
  if (status == 429) return _withDetails(_rateLimited, details);
  if (status == 404) {
    return _withDetails(
      const AppError(
        title: 'الصفحة غير موجودة على المنصة',
        message: 'المنصة لم تجد البيانات المطلوبة لهذا الحساب.',
        hint: 'تأكد أن الحساب يملك هذا المحتوى ثم أعد المحاولة.',
      ),
      details,
    );
  }
  if (status != null && status >= 500) return _withDetails(_server, details);

  if (lower.contains('no chapters') || raw.contains('لا توجد فصول')) {
    return _withDetails(
      const AppError(
        title: 'لا توجد فصول متاحة',
        message: 'لم نعثر على فصول مطابقة لبيانات هذا الحساب.',
        hint: 'تأكد أن الحساب يملك محتوى هذه المنصة ثم حاول مرة أخرى.',
      ),
      details,
    );
  }
  if (lower.contains('no lectures') || lower.contains('locked')) {
    return _withDetails(
      const AppError(
        title: 'المحتوى مغلق على المنصة',
        message: 'يوجد فصل أو درس غير مفتوح لهذا الحساب.',
        hint: 'افتح المحتوى من حساب المدرسة أولًا، أو تواصل مع الدعم.',
      ),
      details,
    );
  }
  if (lower.contains('unsupported') || raw.contains('غير مدعوم')) {
    return _withDetails(
      const AppError(
        title: 'المحرك غير مدعوم',
        message: 'هذا المحرك غير مدعوم في النسخة الحالية من التطبيق.',
        hint: 'حدّث التطبيق أو تواصل مع الدعم.',
      ),
      details,
    );
  }
  if (lower.contains('answers') ||
      lower.contains('non-json') ||
      lower.contains('invalid answers')) {
    return _withDetails(
      const AppError(
        title: 'تعذر تحميل الإجابات',
        message: 'ملف الإجابات غير متاح أو تالف.',
        hint: 'أعد تشغيل التطبيق أو تواصل مع الدعم.',
      ),
      details,
    );
  }
  if (lower.contains('timeout') ||
      lower.contains('timed out') ||
      lower.contains('connection') ||
      lower.contains('socket')) {
    return _withDetails(_network, details);
  }

  return _withDetails(
    const AppError(
      title: 'توقف الحل',
      message: 'توقف الحل قبل الانتهاء.',
      hint: 'راجع السجل ثم أعد المحاولة. إذا تكرر الخطأ تواصل مع الدعم.',
    ),
    details,
  );
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// True when the error only means the backend migration was not applied yet
/// (e.g. a missing RPC). Callers may fall back to local behaviour.
bool isMissingBackendFeature(Object error) {
  if (error is PostgrestException) {
    final code = error.code ?? '';
    final m = error.message.toLowerCase();
    return code == 'PGRST202' ||
        m.contains('could not find the function') ||
        m.contains('schema cache');
  }
  return false;
}

AppError _withDetails(AppError error, String details) => AppError(
      title: error.title,
      message: error.message,
      hint: error.hint,
      details: details,
    );

String _clean(Object error) {
  var text = error.toString().trim();
  text = text.replaceFirst(RegExp(r'^(Exception|SolverStop|Error):\s*'), '');
  return text;
}

bool _hasArabic(String text) => RegExp(r'[\u0600-\u06FF]').hasMatch(text);

String _rawDetails(Object error) {
  final buffer = StringBuffer(error.toString());

  if (error is DioException) {
    final response = error.response;
    if (response != null) {
      buffer.write(
        '\n→ ${response.requestOptions.method} ${response.requestOptions.uri}'
        ' → ${response.statusCode}',
      );
      final data = response.data?.toString();
      if (data != null && data.isNotEmpty) {
        buffer.write('\n${data.length > 500 ? '${data.substring(0, 500)}…' : data}');
      }
    }
  }

  if (error is PostgrestException) {
    buffer.write(
      '\n→ code=${error.code} details=${error.details} hint=${error.hint}',
    );
  }

  return buffer.toString();
}