import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_error.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/engine_provider.dart';
import '../../services/secure_credentials.dart';
import '../../solver/api.dart';
import '../../solver/pace.dart';
import '../../solver/answers.dart';
import '../../solver/qureo_solver.dart';
import '../../solver/sprix_solver.dart';
import '../../widgets/error_view.dart';

/// Severity of a solver log line — colors the log without emoji sniffing.
enum _LogLevel { info, success, error }

class _LogLine {
  final String time;
  final String message;
  final _LogLevel level;
  const _LogLine(this.time, this.message, this.level);
}

class SolvingScreen extends ConsumerStatefulWidget {
  final String engineCode;

  /// 0 = solve the whole engine. >0 = solve only the first N trial chapters.
  final int trialChapters;

  const SolvingScreen({
    super.key,
    required this.engineCode,
    this.trialChapters = 0,
  });

  @override
  ConsumerState<SolvingScreen> createState() => _SolvingScreenState();
}

class _SolvingScreenState extends ConsumerState<SolvingScreen> {
  int _activeTrial = 0;

  String? _boundAccountNorm() =>
      ref.read(profileProvider).valueOrNull?.platformLoginNorm;

  bool _hasFullAccess() {
    final entitlements = ref.read(entitlementsProvider).valueOrNull ?? [];
    return ref.read(engineServiceProvider).hasEntitlement(
          entitlements,
          widget.engineCode,
          null,
          loginNorm: _boundAccountNorm(),
        );
  }

  int _allowedTrialChapters() {
    final info = ref.read(trialInfoProvider).valueOrNull;
    if (info == null ||
        !info.appliesTo(widget.engineCode) ||
        !info.available) {
      return 0;
    }
    return info.chapters;
  }

  int _effectiveTrialChapters() {
    if (_hasFullAccess() || widget.trialChapters <= 0) return 0;
    final allowed = _allowedTrialChapters();
    if (allowed <= 0) return 0;
    return widget.trialChapters.clamp(0, allowed);
  }
  final _loginController = TextEditingController();
  final _passController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_LogLine> _logs = [];

  bool _boost = true;
  bool _running = false;
  double _progress = 0.0;
  String _progressLabel = '';
  AppError? _lastError;

  @override
  void initState() {
    super.initState();
    _loadStoredCredentials();
  }

  /// Prefills the login (from the bound account) and the cached password.
  Future<void> _loadStoredCredentials() async {
    final userId = ref.read(supabaseProvider).auth.currentUser?.id;
    if (userId == null) return;

    final password = await SecureCredentials.readPassword(userId);
    if (!mounted) return;

    final login = ref.read(profileProvider).valueOrNull?.platformLogin;
    setState(() {
      if (login != null && login.isNotEmpty && _loginController.text.isEmpty) {
        _loginController.text = login;
      }
      if (password != null && password.isNotEmpty) {
        _passController.text = password;
      }
    });
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addLog(String msg, [_LogLevel level = _LogLevel.info]) {
    if (!mounted) return;
    final time = DateTime.now();
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
    setState(() {
      _logs.add(_LogLine(timeStr, msg, level));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startSolving() async {
    final loginId = _loginController.text.trim();
    final password = _passController.text.trim();

    if (loginId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال بيانات الدخول للمنصة')),
      );
      return;
    }

    if (!await _ensureAccountBound(loginId)) return;

    // Strict check: after binding, the current account must actually own an
    // unlock (or trial) for this engine. Blocks reusing a purchase on another
    // account.
    if (!_hasFullAccess() && _effectiveTrialChapters() <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'هذا الحساب لا يملك فتح هذه المنصة. اشترِ للمنصة بحسابك الحالي.',
            ),
          ),
        );
      }
      return;
    }

    final userId = ref.read(supabaseProvider).auth.currentUser?.id;
    if (userId != null) {
      await SecureCredentials.savePassword(userId, password);
    }

    _activeTrial = _effectiveTrialChapters();

    setState(() {
      _running = true;
      _progress = 0.0;
      _progressLabel = 'جاري البدء...';
      _lastError = null;
      _logs.clear();
    });

    _addLog(
      _activeTrial > 0
          ? 'بدء التجربة المجانية: ${widget.engineCode} (أول $_activeTrial فصول)'
          : 'بدء حل المنصة كاملة: ${widget.engineCode}',
    );
    _addLog('وضع التسريع (Boost): ${_boost ? 'مفعل' : 'معطل'}');

    final pace = Pace(
      enabled: _boost,
      platform: widget.engineCode,
      log: _addLog,
    );

    try {
      if (widget.engineCode.startsWith('qureo')) {
        await _solveQureo(loginId, password, pace);
      } else if (widget.engineCode.startsWith('sprix')) {
        await _solveSprix(loginId, password, pace);
      } else {
        throw SolverStop('محرك غير مدعوم: ${widget.engineCode}');
      }

      _addLog('اكتمل الحل بنجاح', _LogLevel.success);
    } catch (e) {
      final info = describeError(e, action: 'حل ${widget.engineCode}');
      _addLog(info.title, _LogLevel.error);
      _addLog(info.message);
      if (info.hint != null) _addLog(info.hint!);
      if (info.details != null) _addLog(info.details!);
      if (mounted) setState(() => _lastError = info);
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  /// Binds the platform account on the first solve, and blocks a mismatched
  /// account afterwards. Returns false when solving must not start.
  Future<bool> _ensureAccountBound(String loginId) async {
    final profile = ref.read(profileProvider).valueOrNull;
    final boundLogin = profile?.platformLogin?.trim();
    final isBound = boundLogin != null && boundLogin.isNotEmpty;

    if (isBound && boundLogin != loginId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('هذا الحساب مربوط بكود آخر: $boundLogin')),
      );
      return false;
    }

    if (!isBound) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.t.surface,
          title: Text('تأكيد ربط الحساب',
              style: TextStyle(color: context.t.onSurface)),
          content: Text(
            'سيتم ربط كود الطالب «$loginId» بحسابك بشكل نهائي عند بدء الحل، '
            'ولا يمكن تغييره بعد ذلك إلا بفك الربط.\n\n'
            'تأكد من صحة الكود قبل المتابعة.',
            style: TextStyle(color: context.t.onSurface, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.t.burgundy,
                foregroundColor: Colors.white,
              ),
              child: const Text('ربط ومتابعة'),
            ),
          ],
        ),
      );

      if (confirmed != true) return false;
    }

    // Always call the RPC: it validates the account and stamps any newly
    // created entitlement that does not yet belong to an account.
    try {
      await ref.read(profileProvider.notifier).bindPlatformAccount(loginId);
      ref.invalidate(entitlementsProvider);
      ref.invalidate(trialInfoProvider);
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, e, action: 'ربط الحساب');
      }
      return false;
    }
    return true;
  }

  Future<void> _solveQureo(String loginId, String password, Pace pace) async {
    final course = QureoCourse.of(widget.engineCode);

    final portal = SolverApi(
      baseHeaders: {
        'User-Agent': kUserAgent,
        'Accept': 'application/json, text/plain, */*',
        'Content-Type': 'application/json;charset=UTF-8',
        'Origin': 'https://me-portal.qureo.education',
        'Referer': 'https://me-portal.qureo.education/',
      },
      pace: pace,
    );

    final tp = SolverApi(
      baseHeaders: {
        'User-Agent': kUserAgent,
        'Accept': 'application/json, text/plain, */*',
        'Content-Type': 'application/json;charset=UTF-8',
        'Origin': 'https://me-tp.qureo.education',
        'Referer': 'https://me-tp.qureo.education/',
      },
      jar: portal.cookieJar,
      pace: pace,
    );

    _addLog('تحميل الإجابات المشفرة من الأصول...');
    final answers = await AnswersBundle.getQureo(widget.engineCode);
    _addLog('تم فك تشفير إجابات ${answers.length} فصلاً بنجاح');

    final solver = QureoSolver(
      portal: portal,
      tp: tp,
      log: _addLog,
      pace: pace,
      course: course,
    );

    // Solving is always for the whole engine (or the first N trial chapters);
    // there is no per-chapter paid solve anymore.
    final startNum = int.tryParse(course.rawOf(1) ?? '') ?? (course.baseId + 1);
    final endNum = _activeTrial > 0
        ? int.tryParse(course.rawOf(_activeTrial) ?? '')
        : null;

    await solver.runWith(
      loginId: loginId,
      password: password,
      start: startNum,
      end: endNum,
      answers: answers,
      onProgress: (done, total, label) {
        if (!mounted) return;
        setState(() {
          _progress = total > 0 ? done / total : 0.0;
          _progressLabel = '$label ($done/$total)';
        });
      },
    );
  }

  Future<void> _solveSprix(String loginId, String password, Pace pace) async {
    final isEn = widget.engineCode == 'sprix_en';
    final subject = isEn ? 3 : 7;

    final api = SolverApi(
      baseHeaders: {
        'User-Agent': kUserAgent,
        'Accept': 'application/json, text/plain, */*',
        'Content-Type': 'application/json;charset=UTF-8',
        'Origin': 'https://egy.app.spx-learning-square.com',
        'Referer': 'https://egy.app.spx-learning-square.com/',
      },
      pace: pace,
    );

    _addLog('تحميل إجابات SPRIX المشفرة...');
    final chapters = await AnswersBundle.getSprixChapters(widget.engineCode);
    final tests = await AnswersBundle.getSprixTests(widget.engineCode);
    _addLog('تم تحميل ${chapters.length} فصلاً و ${tests.length} اختباراً');

    final solver = SprixSolver(
      api: api,
      log: _addLog,
      pace: pace,
      subject: subject,
    );

    final startUnit = isEn ? 1 : 19;

    await solver.runWith(
      loginId: loginId,
      password: password,
      start: startUnit,
      chapters: chapters,
      tests: tests,
      maxChapters: _activeTrial > 0 ? _activeTrial : null,
      onProgress: (done, total, label) {
        if (!mounted) return;
        setState(() {
          _progress = total > 0 ? done / total : 0.0;
          _progressLabel = '$label ($done/$total)';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final entitlements = ref.watch(entitlementsProvider);
    final trial = ref.watch(trialInfoProvider);
    final profile = ref.watch(profileProvider);

    // Keep the login field in sync with the bound account once it is known.
    ref.listen(profileProvider, (_, next) {
      final login = next.valueOrNull?.platformLogin?.trim();
      if (login != null && login.isNotEmpty && _loginController.text.isEmpty) {
        _loginController.text = login;
      }
    });

    final boundLogin = profile.valueOrNull?.platformLogin?.trim();
    final isBound = boundLogin != null && boundLogin.isNotEmpty;
    if (isBound && _loginController.text.isEmpty) {
      final login = boundLogin;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _loginController.text.isEmpty) {
          _loginController.text = login;
        }
      });
    }

    final loading =
        (entitlements.isLoading && !entitlements.hasValue) ||
        (trial.isLoading && !trial.hasValue);

    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.engineCode.toUpperCase())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (entitlements.hasError) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.engineCode.toUpperCase())),
        body: ErrorView(
          error: entitlements.error!,
          onRetry: () => ref.invalidate(entitlementsProvider),
        ),
      );
    }

    final hasFull = ref.read(engineServiceProvider).hasEntitlement(
          entitlements.valueOrNull ?? [],
          widget.engineCode,
          null,
          loginNorm: profile.valueOrNull?.platformLoginNorm,
        );
    final requestedTrial = widget.trialChapters;
    final allowedTrial = (() {
      final info = trial.valueOrNull;
      if (info == null ||
          !info.appliesTo(widget.engineCode) ||
          !info.available) {
        return 0;
      }
      return info.chapters;
    })();
    final trialChapters = requestedTrial > 0
        ? requestedTrial.clamp(0, allowedTrial)
        : 0;
    final allowed = hasFull || trialChapters > 0;

    if (!allowed) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.engineCode.toUpperCase())),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline,
                    color: context.t.onSurfaceVariant, size: 52),
                const SizedBox(height: 16),
                Text(
                  'هذه المنصة غير مفتوحة',
                  style: TextStyle(
                    color: context.t.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'افتح المنصة كاملة أو ابدأ التجربة المجانية من صفحة المحرك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.t.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('العودة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(!hasFull && trialChapters > 0
            ? 'تجربة ${widget.engineCode.toUpperCase()} ($trialChapters فصول)'
            : 'حل ${widget.engineCode.toUpperCase()} كاملة'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Credentials & Boost Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.t.surface,
                borderRadius: BorderRadius.circular(SolverTheme.radiusCard),
                border: Border.all(color: context.t.line),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _loginController,
                          enabled: !_running && !isBound,
                          decoration: InputDecoration(
                            labelText: 'كود الطالب',
                            prefixIcon: const Icon(Icons.person_outline),
                            helperText: isBound ? 'الحساب المربوط' : null,
                            helperStyle: TextStyle(
                              color: context.t.success,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _passController,
                          enabled: !_running,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'كلمة السر',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Switch(
                            value: _boost,
                            onChanged: _running
                                ? null
                                : (v) => setState(() => _boost = v),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'وضع التسريع (Boost)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _boost
                                  ? context.t.onSurface
                                  : context.t.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _running ? null : _startSolving,
                        icon: _running
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(_running ? 'جاري الحل...' : 'بدء الحل'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.t.burgundy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Progress Bar
            if (_progress > 0 || _running) ...[
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: context.t.surfaceVariant,
                valueColor:
                    AlwaysStoppedAnimation<Color>(context.t.burgundy),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '$_progressLabel ${(_progress * 100).round()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.t.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_lastError != null) ...[
              _ErrorBanner(
                info: _lastError!,
                onRetry: _running ? null : _startSolving,
                onShowDetails: () =>
                    showErrorDetailsDialog(context, _lastError!),
              ),
              const SizedBox(height: 12),
            ],

            // Live log panel
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1917),
                  borderRadius: BorderRadius.circular(SolverTheme.radiusCard),
                ),
                child: _logs.isEmpty
                    ? Center(
                        child: Text(
                          'اضغط "بدء الحل" لبدء التشغيل على جهازك.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return _logRow(_logs[index]);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logRow(_LogLine line) {
    final Color color;
    switch (line.level) {
      case _LogLevel.success:
        color = const Color(0xFF8FD3B2);
      case _LogLevel.error:
        color = const Color(0xFFFF9891);
      case _LogLevel.info:
        color = const Color(0xFFD9D6D2);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: line.time,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.35),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const TextSpan(text: '  '),
                  TextSpan(text: line.message),
                ],
              ),
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12.5,
                height: 1.6,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final AppError info;
  final VoidCallback? onRetry;
  final VoidCallback onShowDetails;

  const _ErrorBanner({
    required this.info,
    required this.onRetry,
    required this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.t.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.t.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline,
                  color: context.t.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  info.title,
                  style: TextStyle(
                    color: context.t.error,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            info.message,
            style: TextStyle(
              color: context.t.onSurface.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (info.hint != null) ...[
            const SizedBox(height: 4),
            Text(
              info.hint!,
              style: TextStyle(
                color: context.t.onSurface.withValues(alpha: 0.55),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (onRetry != null)
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('إعادة المحاولة'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              if (info.details != null)
                TextButton.icon(
                  onPressed: onShowDetails,
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('عرض التفاصيل'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.t.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}