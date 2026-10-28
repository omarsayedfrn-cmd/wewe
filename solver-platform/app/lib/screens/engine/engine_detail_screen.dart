import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_error.dart';
import '../../core/theme.dart';
import '../../models/engine.dart';
import '../../providers/engine_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/auth_provider.dart';
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
            child: CircularProgressIndicator(color: SolverTheme.gold)),
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
              child: CircularProgressIndicator(color: SolverTheme.gold),
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

        final hasFull = ref
            .read(engineServiceProvider)
            .hasEntitlement(userEntitlements, engineCode, null);

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
                    gradient: LinearGradient(
                      colors: [
                        SolverTheme.burgundy.withValues(alpha: 0.3),
                        SolverTheme.surface,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SolverTheme.surfaceVariant),
                  ),
                  child: Column(
                    children: [
                      Text(engine.icon,
                          style: const TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        engine.displayName(lang),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: SolverTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${engine.maxChapter} فصل • ${engine.platform.toUpperCase()}',
                        style: TextStyle(
                          color: SolverTheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (hasFull)
                  _buildFullOpenCard(
                    context,
                    engine,
                    onSolve: () =>
                        context.push('/engine/${engine.code}/solve'),
                  )
                else ...[
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
                    _buildTrialFinishedCard(),
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
                  hasFull
                      ? 'سيتم حل جميع فصول المنصة تلقائيًا من البداية حتى النهاية.'
                      : trialApplies
                          ? 'التجربة تحل أول $trialChapters فصول فقط. لفتح باقي المنصة استخدم زر الفتح الكامل.'
                          : 'الفتح الكامل يحل جميع فصول المنصة دفعة واحدة.',
                ),
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
    required VoidCallback onSolve,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SolverTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SolverTheme.success.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Chip(
            avatar: Icon(Icons.check_circle,
                color: SolverTheme.success, size: 18),
            label: Text('المنصة مفتوحة بالكامل'),
            backgroundColor: SolverTheme.surfaceVariant,
            labelStyle: TextStyle(color: SolverTheme.success),
          ),
          const SizedBox(height: 12),
          const Text(
            'يمكنك الآن حل كل فصول المنصة بضغطة واحدة.',
            style: TextStyle(color: SolverTheme.onSurface, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onSolve,
            icon: const Icon(Icons.play_circle_fill),
            label: const Text('ابدأ حل المنصة كاملة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SolverTheme.gold,
              foregroundColor: Colors.black,
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
        color: SolverTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SolverTheme.gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard, color: SolverTheme.gold),
              const SizedBox(width: 8),
              Text(
                'تجربة مجانية: $chapters فصول',
                style: const TextStyle(
                  color: SolverTheme.gold,
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
              color: SolverTheme.onSurface.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _startTrial(context, ref, engine, chapters),
            icon: const Icon(Icons.rocket_launch),
            label: const Text('ابدأ التجربة المجانية'),
            style: OutlinedButton.styleFrom(
              foregroundColor: SolverTheme.gold,
              side: const BorderSide(color: SolverTheme.gold),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialFinishedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: SolverTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SolverTheme.error.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: SolverTheme.error, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'تم استخدام التجربة المجانية. افتح المنصة كاملة للمتابعة.',
              style: TextStyle(color: SolverTheme.error, fontSize: 13),
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
        color: SolverTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SolverTheme.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'فتح المنصة كاملة',
            style: TextStyle(
              color: SolverTheme.onSurface,
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
              color: SolverTheme.onSurface.withValues(alpha: 0.7),
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
              backgroundColor: SolverTheme.burgundy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SolverTheme.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              color: SolverTheme.onSurface.withValues(alpha: 0.6), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: SolverTheme.onSurface.withValues(alpha: 0.7),
                fontSize: 12,
                height: 1.5,
              ),
            ),
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
        backgroundColor: SolverTheme.surface,
        title: const Text('تأكيد الشراء',
            style: TextStyle(color: SolverTheme.onSurface)),
        content: Text(
          'فتح ${engine.displayName("ar")} بالكامل بـ $cost عملة؟\nسيتم حل جميع الفصول دفعة واحدة.',
          style: const TextStyle(color: SolverTheme.onSurface),
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
                    const SnackBar(content: Text('تم الفتح بنجاح ✅')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  showErrorSnack(context, e, action: 'شراء المنصة');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SolverTheme.gold,
              foregroundColor: Colors.black,
            ),
            child: const Text('شراء'),
          ),
        ],
      ),
    );
  }
}