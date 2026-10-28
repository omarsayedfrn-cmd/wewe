import 'dart:math';

/// Per-session pacing governor for Boost mode.
class Pace {
  static const double scaleSprix = 0.03;
  static const double scaleQureo = 0.04;
  static const int floorMs = 20;
  static const double jitter = 0.20;
  static const int maxIncidents = 3;
  static const int backoffBaseMs = 15000;

  final bool enabled;
  final String platform;
  final void Function(String message) log;

  final Random _rnd = Random();
  late double effectiveScale;
  int incidents = 0;
  bool disabled = false;

  Pace({
    required this.enabled,
    required this.platform,
    required this.log,
  }) {
    effectiveScale = enabled ? scaleFor(platform) : 1.0;
  }

  static double scaleFor(String platform) {
    if (platform == 'sprix' || platform == 'sprix_en') {
      return scaleSprix;
    }
    return scaleQureo;
  }

  static String fmtScale(double v) => ((v * 100).round() / 100.0).toString();

  /// Scaled delay for solver work-loop steps (jittered, floored)
  Future<void> step(int baseMs) async {
    if (!enabled || disabled) {
      await Future.delayed(Duration(milliseconds: baseMs));
      return;
    }
    final jittered = baseMs * effectiveScale * (1.0 - jitter + _rnd.nextDouble() * jitter * 2.0);
    final delayMs = max(floorMs, jittered.round());
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  /// Unscaled delay for login / session bootstrap steps (never boosted)
  Future<void> auth(int baseMs) async {
    await Future.delayed(Duration(milliseconds: baseMs));
  }

  /// Called on HTTP 429: escalate, cool down, maybe disable
  Future<void> onRateLimit(int attempt) async {
    if (enabled && !disabled) {
      incidents++;
      if (incidents >= maxIncidents) {
        disabled = true;
        effectiveScale = 1.0;
        log('تنبيه: تم الوصول لحد الطلبات ($incidents مرات) — تم تعطيل Boost مؤقتًا');
      } else {
        effectiveScale = min(1.0, effectiveScale + 0.2);
        log('تنبيه: المنصة طلبت تقليل الطلبات (429) — تم إبطاء Boost إلى ×${fmtScale(effectiveScale)}');
      }
    }
    final backoff = backoffBaseMs + attempt * 5000 + _rnd.nextInt(5000);
    log('انتظار ${backoff ~/ 1000} ثانية بسبب حد الطلبات...');
    await Future.delayed(Duration(milliseconds: backoff));
  }

  /// Called on HTTP 403 (locked/forbidden): log but NO cooldown, fail fast
  Future<void> onForbidden(String context) async {
    if (enabled) log('توقف: تم رفض الوصول إلى $context (403) — لن تتم إعادة المحاولة');
  }
}
