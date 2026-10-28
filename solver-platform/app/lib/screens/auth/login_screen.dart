import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/error_view.dart';

/// Phone + Password Login & Registration Screen, with admin WhatsApp review notice.
/// Google Sign-In code is preserved.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  bool _isRegister = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Launch WhatsApp chat with the Admin
  Future<void> _openWhatsApp() async {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    String message;
    if (_isRegister && phone.isNotEmpty) {
      message = 'مرحباً، قمت بالتسجيل في تطبيق Solver باسم ($name) ورقم الهاتف ($phone) وأرغب في مراجعة وتفعيل حسابي.';
    } else if (phone.isNotEmpty) {
      message = 'مرحباً، لدي حساب في تطبيق Solver برقم ($phone) وأرغب في مراجعته وتفعيله.';
    } else {
      message = 'مرحباً، أرغب في الاستفسار عن تفعيل حسابي في تطبيق Solver.';
    }

    final url = 'https://wa.me/${AppConstants.adminWhatsAppNumber}?text=${Uri.encodeComponent(message)}';
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, e, action: 'فتح واتساب');
      }
    }
  }

  /// Handle Phone + Password Submit (Login or Register)
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    setState(() => _loading = true);

    try {
      if (_isRegister) {
        final name = _nameController.text.trim();
        final res = await ref.read(authServiceProvider).signUpWithPhonePassword(
              phone: phone,
              password: password,
              fullName: name,
            );

        if (!mounted) return;

        // If email confirmation is required or session is pending
        if (res.session == null) {
          _showReviewBottomSheet(isPendingSession: true);
        } else {
          _showReviewBottomSheet(isPendingSession: false);
        }
      } else {
        await ref.read(authServiceProvider).signInWithPhonePassword(
              phone: phone,
              password: password,
            );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnack(
          context,
          e,
          action: _isRegister ? 'إنشاء حساب' : 'تسجيل الدخول',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Dialog shown on successful registration
  void _showReviewBottomSheet({required bool isPendingSession}) {
    showModalBottomSheet(
      context: context,
      isDismissible: !isPendingSession,
      backgroundColor: context.t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: context.t.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(
              Icons.mark_chat_read_rounded,
              color: context.t.success,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              'تم إرسال طلبك بنجاح',
              style: TextStyle(
                color: context.t.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'حسابك قيد المراجعة حالياً من قِبل الإدارة.\nسيتم التواصل معك عبر WhatsApp لتأكيد البيانات وتفعيل المحركات.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.t.onSurface,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // WhatsApp Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openWhatsApp();
                },
                icon: const Icon(Icons.chat, color: Colors.white),
                label: const Text('تواصل مع الإدارة عبر WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!isPendingSession)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('متابعة إلى التطبيق'),
              ),
          ],
        ),
      ),
    );
  }

  /// Google Sign-In (Code preserved)
  // ignore: unused_element
  Future<void> _signInGoogle() async {
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, e, action: 'تسجيل الدخول عبر Google');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: context.t.background,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          'assets/branding/logo.png',
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // App name
                      Text(
                        'Solver',
                        style: TextStyle(
                          color: context.t.onSurface,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'حل واجبات QUREO و SPRIX',
                        style: TextStyle(
                          color: context.t.onSurface.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Mode Switcher (Login / Register)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: context.t.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.t.surfaceVariant),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isRegister = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !_isRegister ? context.t.burgundy : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'تسجيل الدخول',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: !_isRegister ? Colors.white : context.t.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isRegister = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _isRegister ? context.t.burgundy : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'حساب جديد',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _isRegister ? Colors.white : context.t.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Card with Input Fields
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.t.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.t.surfaceVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Full Name (Only for registration)
                            if (_isRegister) ...[
                              TextFormField(
                                controller: _nameController,
                                textDirection: TextDirection.rtl,
                                decoration: InputDecoration(
                                  labelText: 'اسم الطالب ثلاثي',
                                  hintText: 'مثال: أحمد محمد علي',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (val) {
                                  if (_isRegister && (val == null || val.trim().length < 3)) {
                                    return 'يرجى إدخال اسم الطالب ثلاثي';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Phone Number Field
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                labelText: 'رقم الهاتف / WhatsApp',
                                hintText: '01012345678',
                                prefixIcon: const Icon(Icons.phone_android),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'يرجى إدخال رقم الهاتف';
                                }
                                final digits = val.replaceAll(RegExp(r'\D'), '');
                                if (digits.length < 9) {
                                  return 'رقم الهاتف غير صالح';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: context.t.onSurfaceVariant,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.length < 6) {
                                  return 'كلمة المرور 6 أحرف على الأقل';
                                }
                                return null;
                              },
                            ),

                            // Confirm Password Field (Only for registration)
                            if (_isRegister) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirm,
                                textDirection: TextDirection.ltr,
                                decoration: InputDecoration(
                                  labelText: 'تأكيد كلمة المرور',
                                  prefixIcon: const Icon(Icons.lock_reset),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                                      color: context.t.onSurfaceVariant,
                                    ),
                                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (val) {
                                  if (_isRegister && val != _passwordController.text) {
                                    return 'كلمة المرور غير متطابقة';
                                  }
                                  return null;
                                },
                              ),
                            ],

                            const SizedBox(height: 20),

                            // Submit Button
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.t.burgundy,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 6,
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _isRegister ? 'إنشاء حساب ومراجعة' : 'تسجيل الدخول',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Admin Review & WhatsApp Notice Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: context.t.surfaceVariant,
                          borderRadius: BorderRadius.circular(SolverTheme.radiusControl),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              color: context.t.onSurfaceVariant,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'تتم مراجعة وتفعيل الحسابات والتواصل معك عبر WhatsApp من قِبل الإدارة.',
                                style: TextStyle(
                                  color: context.t.onSurface.withValues(alpha: 0.85),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Google Sign-In Secondary Option (disabled — coming soon)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed: null,
                            style: TextButton.styleFrom(
                              foregroundColor: context.t.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            icon: Icon(
                              Icons.account_circle_outlined,
                              size: 20,
                              color: context.t.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            label: Text(
                              'أو تسجيل الدخول بحساب Google',
                              style: TextStyle(
                                color: context.t.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'قريبًا',
                            style: TextStyle(
                              color: context.t.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Footer
                      Text(
                        'Developed by Omar Sayed',
                        style: TextStyle(
                          color: context.t.onSurfaceVariant
                              .withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}