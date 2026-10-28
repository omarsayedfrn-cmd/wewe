import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/error_view.dart';

/// Multi-step onboarding screen (grade → track → language → confirm).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  String? _grade;
  String? _track;
  String? _language;
  String _referralCode = '';
  bool _loading = false;

  int get _totalSteps {
    if (_grade == AppConstants.grade2) return 4; // grade + track + lang + confirm
    return 3; // grade + lang + confirm
  }

  Future<void> _confirmOnboarding() async {
    setState(() => _loading = true);
    try {
      await ref.read(profileProvider.notifier).createProfile(
            grade: _grade!,
            track: _track,
            language: _language!,
            referredBy: _referralCode.isNotEmpty ? _referralCode : null,
          );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, e, action: 'إتمام إنشاء الحساب');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _nextStep() {
    setState(() => _step++);
  }

  void _prevStep() {
    if (_step > 0) setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    // If the profile is already locked, onboarding is done — never show it
    // again (e.g. after a sign-in race or a manual deep link).
    final profile = ref.watch(profileProvider);
    if (profile is AsyncData<Profile?> &&
        profile.value != null &&
        profile.value!.onboardLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home');
      });
    }

    return Scaffold(
      backgroundColor: SolverTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: _prevStep,
              )
            : null,
        title: Text('الخطوة ${_step + 1} من $_totalSteps'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    // Determine logical step based on grade
    if (_step == 0) return _buildGradeStep();
    if (_grade == AppConstants.grade2) {
      if (_step == 1) return _buildTrackStep();
      if (_step == 2) return _buildLanguageStep();
      if (_step == 3) return _buildConfirmStep();
    } else {
      if (_step == 1) return _buildLanguageStep();
      if (_step == 2) return _buildConfirmStep();
    }
    return const SizedBox.shrink();
  }

  Widget _buildGradeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اختر المرحلة الدراسية',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: SolverTheme.gold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'هذا الاختيار نهائي ولا يمكن تغييره بعد التسجيل',
          style: TextStyle(
            color: SolverTheme.onSurface.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 40),
        _buildOptionCard(
          title: 'أولى ثانوي',
          subtitle: 'QUREO جافاسكريبت (42 فصل)',
          icon: '📚',
          selected: _grade == AppConstants.grade1,
          onTap: () {
            setState(() {
              _grade = AppConstants.grade1;
              _track = null;
            });
          },
        ),
        const SizedBox(height: 16),
        _buildOptionCard(
          title: 'تانية ثانوي',
          subtitle: 'اختر المسار في الخطوة التالية',
          icon: '🎓',
          selected: _grade == AppConstants.grade2,
          onTap: () {
            setState(() => _grade = AppConstants.grade2);
          },
        ),
        const Spacer(),
        _buildNextButton(enabled: _grade != null),
      ],
    );
  }

  Widget _buildTrackStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اختر المسار',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: SolverTheme.gold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'المسار يحدد المحركات المتاحة لك',
          style: TextStyle(
            color: SolverTheme.onSurface.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 32),
        ...AppConstants.trackLabels.entries.map((entry) {
          final trackKey = entry.key;
          final trackLabel = entry.value;
          final icon = AppConstants.trackIcons[trackKey] ?? '📖';
          final subtitle = trackKey == AppConstants.trackEngineering
              ? 'SPRIX + QUREO + QUREO2 (بايثون)'
              : 'SPRIX (الثقافة المالية)';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildOptionCard(
              title: trackLabel,
              subtitle: subtitle,
              icon: icon,
              selected: _track == trackKey,
              onTap: () => setState(() => _track = trackKey),
            ),
          );
        }),
        const Spacer(),
        _buildNextButton(enabled: _track != null),
      ],
    );
  }

  Widget _buildLanguageStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اختر اللغة',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: SolverTheme.gold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'لا يمكن تغيير اللغة بعد التسجيل',
          style: TextStyle(
            color: SolverTheme.onSurface.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 40),
        _buildOptionCard(
          title: 'عام',
          subtitle: 'المحركات باللغة العربية',
          icon: '🇪🇬',
          selected: _language == AppConstants.langAr,
          onTap: () => setState(() => _language = AppConstants.langAr),
        ),
        const SizedBox(height: 16),
        _buildOptionCard(
          title: 'لغات',
          subtitle: 'المحركات باللغة الإنجليزية',
          icon: '🇬🇧',
          selected: _language == AppConstants.langEn,
          onTap: () => setState(() => _language = AppConstants.langEn),
        ),
        const Spacer(),
        _buildNextButton(enabled: _language != null),
      ],
    );
  }

  Widget _buildConfirmStep() {
    final engines = AppConstants.enginesForStudent(
      grade: _grade!,
      track: _track,
      language: _language!,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تأكيد الاختيارات',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: SolverTheme.gold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SolverTheme.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: SolverTheme.error.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: SolverTheme.error, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'هذه الاختيارات نهائية ولا يمكن تغييرها',
                  style: TextStyle(color: SolverTheme.error, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Summary cards
        _buildSummaryRow(
            'المرحلة', AppConstants.gradeLabels[_grade] ?? ''),
        if (_track != null)
          _buildSummaryRow(
              'المسار', AppConstants.trackLabels[_track] ?? ''),
        _buildSummaryRow(
            'اللغة', AppConstants.languageLabels[_language] ?? ''),
        const SizedBox(height: 16),
        const Divider(color: SolverTheme.surfaceVariant),
        const SizedBox(height: 16),
        const Text(
          'المحركات المتاحة:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: SolverTheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ...engines.map((code) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    AppConstants.engineIcons[code] ?? '📦',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppConstants.engineLabels[code] ?? code,
                    style: const TextStyle(
                        color: SolverTheme.onSurface, fontSize: 16),
                  ),
                ],
              ),
            )),

        const SizedBox(height: 24),

        // Referral code input
        TextField(
          decoration: const InputDecoration(
            labelText: 'كود الإحالة (اختياري)',
            prefixIcon: Icon(Icons.card_giftcard, color: SolverTheme.gold),
          ),
          onChanged: (v) => _referralCode = v.trim(),
        ),

        const Spacer(),

        // Confirm button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _loading ? null : _confirmOnboarding,
            style: ElevatedButton.styleFrom(
              backgroundColor: SolverTheme.gold,
              foregroundColor: Colors.black,
            ),
            child: _loading
                ? const CircularProgressIndicator(
                    color: Colors.black, strokeWidth: 2)
                : const Text(
                    'تأكيد وبدء الاستخدام',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required String icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected
              ? SolverTheme.burgundy.withValues(alpha: 0.2)
              : SolverTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? SolverTheme.gold : SolverTheme.surfaceVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: selected ? SolverTheme.gold : SolverTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: SolverTheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: SolverTheme.gold, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 16,
              color: SolverTheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: SolverTheme.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton({required bool enabled}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: enabled ? _nextStep : null,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('التالي', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, size: 18),
          ],
        ),
      ),
    );
  }
}
