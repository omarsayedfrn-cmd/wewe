import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_error.dart';
import '../../core/theme.dart';
import '../../models/engine.dart';
import '../../providers/engine_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/secure_credentials.dart';
import '../../widgets/error_view.dart';

/// Engine detail screen — full-engine purchase + optional free trial.
class EngineDetailScreen extends ConsumerWidget {
  final String engineCode;

  const EngineDetailScreen({super.key, required this.engineCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEngines = ref.watch(allEnginesProvider);
    final entitlements = ref.watch(entitlementsProvider);
    final pricing = ref.watch(pricingProvider);
    final profile = ref.watch(profileProvider);
    final trial = ref.watch(trialInfoProvider);
    final lang = profile.valueOrNull?.language ?? 'ar';

    return allEngines.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(
            child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          error: e,
          onRetry: () => ref.invalidate(allEnginesProvider),
        ),
      ),
      data: (engines) {
        if ((entitlements.isLoading && !entitlements.hasValue) ||
            (pricing.isLoading && !pricing.hasValue)) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (entitlements.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorView(
              error: entitlements.error!,
              onRetry: () => ref.invalidate(entitlementsProvider),
            ),
          );
        }
        if (pricing.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorView(
              error: pricing.error!,
              onRetry: () => ref.invalidate(pricingProvider),
            ),
          );
        }

        final engine = engines.firstWhere(
          (e) => e.code == engineCode,
          orElse: () => Engine(
            code: engineCode,
            nameAr: engineCode,
            nameEn: engineCode,
            platform: '',
            course: '',
            language: 'ar',
            maxChapter: 0,
          ),
        );

        final userEntitlements = entitlements.valueOrNull ?? [];
        final pricingList = pricing.valueOrNull ?? [];
        final fullPrice = pricingList
            .where((p) => p.engineCode == engineCode && p.kind == 'full')
            .map((p) => p.cost)
            .firstOrNull;

        final boundLogin = profile.valueOrNull?.platformLogin?.trim();
        final isBound = boundLogin != null && boundLogin.isNotEmpty;
        final loginNorm = profile.valueOrNull?.platformLoginNorm;

        final service = ref.read(engineServiceProvider);
        // Owned and usable now: stamped for the bound account, or still
        // unstamped (purchased before the first solve).
        final hasFull =
            service.hasEntitlement(userEntitlements, engineCode, null,
                loginNorm: loginNorm);

        final trialInfo = trial.valueOrNull;
        final trialApplies = trialInfo != null &&
            trialInfo.appliesTo(engineCode) &&
            trialInfo.available;
        final trialChapters = trialApplies
            ? trialInfo.chapters.clamp(1, engine.maxChapter == 0 ? 1 : engine.maxChapter)
            : 0;

        return Scaffold(
          appBar: AppBar(
            title: Text(engine.displayName(lang)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Engine header card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.t.surface,
                    borderRadius:
                        BorderRadius.circular(SolverTheme.radiusCard),
                    border: Border.all(color: context.t.line),
                  ),
                  child: Column(
                    children: [
                      Icon(engine.icon,
                          size: 44, color: context.t.burgundy),
                      const SizedBox(height: 12),
                      Text(
                        engine.displayName(lang),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: context.t.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${engine.maxChapter} فصل · ${engine.platformLabel}',
                        style: TextStyle(
                          color: context.t.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (isBound)
                  _buildAccountCard(context, ref, boundLogin),

                if (hasFull)
                  _buildFullOpenCard(
                    context,
                    engine,
                    note: isBound
                        ? null
                        : 'هذه المنصة مفتوحة. اضغط «ابدأ حل المنصة» لربط حسابك وبدء الحل.',
                    onSolve: () =>
                        context.push('/engine/${engine.code}/solve'),
                  ),

                if (!hasFull) ...[
                  if (trialApplies)
                    _buildTrialCard(
                      context,
                      ref,
                      engine,
                      trialChapters,
                    ),
                  if (trialInfo != null &&
                      trialInfo.appliesTo(engineCode) &&
                      !trialInfo.available)
                    _buildTrialFinishedCard(context),
                ],

                if (!hasFull) ...[
                  const SizedBox(height: 16),
                  _buildPurchaseCard(
                    context,
                    ref,
                    engine,
                    fullPrice,
                  ),
                ],

                const SizedBox(height: 16),
                _buildInfoCard(
                  context,
                  hasFull
                      ? 'سيتم حل جميع فصول المنصة تلقائيًا من البداية حتى النهاية.'
                      : trialApplies
                          ? 'التجربة تحل أول $trialChapters فصول فقط. لفتح باقي المنصة استخدم زر الفتح الكامل.'
                          : 'الفتح الكامل يحل جميع فصول المنصة دفعة واحدة.',
                ),

                if (!isBound) ...[
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    context,
                    'سيتم ربط أول كود طالب تحل به بحسابك، ولا يمكن تغييره بعد بدء الحل.',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullOpenCard(
    BuildContext context,
    Engine engine, {
    String? note,
    required VoidCallback onSolve,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.t.success.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Chip(
            avatar: Icon(Icons.check_circle,
                color: context.t.success, size: 18),
            label: Text('المنصة مفتوحة بالكامل'),
            backgroundColor: context.t.surfaceVariant,
            labelStyle: TextStyle(color: context.t.success),
          ),
          const SizedBox(height: 12),
          Text(
            'يمكنك الآن حل كل فصول المنصة بضغطة واحدة.',
            style: TextStyle(color: context.t.onSurface, fontSize: 14),
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note,
              style: TextStyle(
                color: context.t.gold,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onSolve,
            icon: const Icon(Icons.play_circle_fill),
            label: const Text('ابدأ حل المنصة كاملة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.t.burgundy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialCard(
    BuildContext context,
    WidgetRef ref,
    Engine engine,
    int chapters,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.t.surface,
        borderRadius: BorderRadius.circular(SolverTheme.radiusCard),
        border: Border.all(color: context.t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard),
              const SizedBox(width: 8),
              Text(
                'تجربة مجانية: $chapters فصول',
                style: TextStyle(
                  color: context.t.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'جرّب أول $chapters فصول من المنصة مجانًا قبل الفتح الكامل.',
            style: TextStyle(
              color: context.t.onSurface.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _startTrial(context, ref, engine, chapters),
            icon: const Icon(Icons.rocket_launch),
            label: const Text('ابدأ التجربة المجانية'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialFinishedCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.t.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.t.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: context.t.error, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'تم استخدام التجربة المجانية. افتح المنصة كاملة للمتابعة.',
              style: TextStyle(color: context.t.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseCard(
    BuildContext context,
    WidgetRef ref,
    Engine engine,
    int? fullPrice,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.t.surface,
        borderRadius: BorderRadius.circular(SolverTheme.radiusCard),
        border: Border.all(color: context.t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'فتح المنصة كاملة',
            style: TextStyle(
              color: context.t.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fullPrice != null
                ? 'افتح جميع فصول ${engine.displayName("ar")} بسعر $fullPrice عملة.'
                : 'السعر غير متاح حاليًا، يرجى التواصل مع الإدارة.',
            style: TextStyle(
              color: context.t.onSurface.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: fullPrice == null
                ? null
                : () => _confirmPurchase(
                      context,
                      ref,
                      engine,
                      fullPrice,
                    ),
            icon: const Icon(Icons.lock_open),
            label: Text(fullPrice != null
                ? 'فتح الكل بـ $fullPrice عملة'
                : 'غير متاح'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.t.burgundy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.t.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              color: context.t.onSurface.withValues(alpha: 0.6), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.t.onSurface.withValues(alpha: 0.7),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    WidgetRef ref,
    String login,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.t.surface,
        borderRadius: BorderRadius.circular(SolverTheme.radiusCard),
        border: Border.all(color: context.t.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined, color: context.t.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                'الحساب المربوط',
                style: TextStyle(
                  color: context.t.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            login,
            style: TextStyle(
              color: context.t.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'هذا الحساب مربوط بكل المنصات المفتوحة ويُستخدم عند الحل.',
            style: TextStyle(
              color: context.t.onSurface.withValues(alpha: 0.6),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => _confirmUnbind(context, ref),
            icon: const Icon(Icons.link_off),
            label: const Text('فك الربط / حساب جديد'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmUnbind(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.t.surface,
        title: Text('فك ربط الحساب',
            style: TextStyle(color: context.t.onSurface)),
        content: Text(
          'أنت اشتريت حق استخدام حساب واحد فقط. فكّ الربط يلغي اشتراكاتك في '
          'كل المحركات نهائيًا، وتضطر تشتري من جديد لو حبيت تفتح أي منصة تانية.',
          style: TextStyle(color: context.t.onSurface, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(profileProvider.notifier).unbindPlatformAccount();
                ref.invalidate(entitlementsProvider);
                ref.invalidate(trialInfoProvider);
                final userId =
                    ref.read(supabaseProvider).auth.currentUser?.id;
                if (userId != null) {
                  await SecureCredentials.clear(userId);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم فك ربط الحساب')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  showErrorSnack(context, e, action: 'فك ربط الحساب');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.t.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('فك الربط'),
          ),
        ],
      ),
    );
  }

  Future<void> _startTrial(
    BuildContext context,
    WidgetRef ref,
    Engine engine,
    int chapters,
  ) async {
    // Best-effort: persist the trial server-side (marks trial_used and creates
    // the trial entitlement). If the migration is not applied yet, the app
    // still lets the student solve the configured trial chapters locally.
    try {
      await ref.read(engineServiceProvider).claimTrial();
      ref.invalidate(entitlementsProvider);
      ref.invalidate(profileProvider);
    } catch (e) {
      if (!isMissingBackendFeature(e)) {
        if (context.mounted) {
          showErrorSnack(context, e, action: 'تفعيل التجربة المجانية');
        }
        return;
      }
      debugPrint('[Trial] backend not migrated, using local trial: $e');
    }

    if (context.mounted) {
      context.push('/engine/${engine.code}/solve?trial=$chapters');
    }
  }

  void _confirmPurchase(
    BuildContext context,
    WidgetRef ref,
    Engine engine,
    int cost,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.t.surface,
        title: Text('تأكيد الشراء',
            style: TextStyle(color: context.t.onSurface)),
        content: Text(
          'فتح ${engine.displayName("ar")} بالكامل بـ $cost عملة؟\nسيتم حل جميع الفصول دفعة واحدة.',
          style: TextStyle(color: context.t.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(engineServiceProvider).purchaseEngine(
                      engineCode: engine.code,
                      scope: 'full',
                    );
                ref.invalidate(entitlementsProvider);
                ref.invalidate(walletProvider);
                ref.invalidate(trialInfoProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم فتح المنصة')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  showErrorSnack(context, e, action: 'شراء المنصة');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.t.burgundy,
              foregroundColor: Colors.white,
            ),
            child: const Text('شراء، فتح الكل'),
          ),
        ],
      ),
    );
  }
}