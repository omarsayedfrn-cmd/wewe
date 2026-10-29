import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/secure_credentials.dart';
import '../../widgets/error_view.dart';

/// Profile tab — user info, referral code, settings.
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Avatar & name
                CircleAvatar(
                  radius: 45,
                  backgroundColor: context.t.burgundy,
                  backgroundImage: profile.avatar != null
                      ? NetworkImage(profile.avatar!)
                      : null,
                  child: profile.avatar == null
                      ? Text(
                          (profile.displayName ?? 'S')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 36,
                            color: context.t.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  profile.displayName ?? 'مستخدم',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.t.onSurface,
                  ),
                ),
                if (profile.isMerchant) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.t.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: context.t.gold.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_outlined,
                            size: 15, color: context.t.gold),
                        const SizedBox(width: 6),
                        Text(
                          'حساب تاجر',
                          style: TextStyle(
                            color: context.t.gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  ref.read(supabaseProvider).auth.currentUser?.email ?? '',
                  style: TextStyle(
                    color: context.t.onSurface.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),

                // Quick stats
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'الرصيد',
                        value: walletAsync.when(
                          data: (w) => '${w.balance}',
                          loading: () => '...',
                          error: (_, __) => 'تعذر',
                        ),
                        icon: Icons.account_balance_wallet,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'المرحلة',
                        value: AppConstants.gradeLabels[profile.grade] ?? '—',
                        icon: Icons.school,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (profile.track != null)
                      Expanded(
                        child: _StatCard(
                          label: 'المسار',
                          value:
                              AppConstants.trackLabels[profile.track] ?? '—',
                          icon: Icons.route,
                        ),
                      ),
                    if (profile.track != null) const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'اللغة',
                        value: AppConstants.languageLabels[profile.language] ??
                            '—',
                        icon: Icons.language,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Referral code (students only — merchants have no referral)
                if (!profile.isMerchant)
                  Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.t.surface,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: context.t.gold.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.card_giftcard,
                              color: context.t.gold, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'كود الإحالة',
                            style: TextStyle(
                              color: context.t.gold,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            profile.referralCode,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: context.t.onSurface,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: Icon(Icons.copy,
                                color: context.t.gold),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: profile.referralCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('تم نسخ كود الإحالة')),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'شارك الكود مع أصدقائك واحصل على مكافآت',
                        style: TextStyle(
                          color:
                              context.t.onSurface.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Bound platform account
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.t.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.t.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.badge_outlined,
                              color: context.t.onSurfaceVariant, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'حساب المنصة المربوط',
                            style: TextStyle(
                              color: context.t.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        profile.hasBoundAccount
                            ? profile.platformLogin!
                            : 'لم يتم الربط بعد',
                        style: TextStyle(
                          color: profile.hasBoundAccount
                              ? context.t.onSurface
                              : context.t.onSurface.withValues(alpha: 0.5),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'يُربط تلقائيًا عند أول حل، ويُستخدم لكل المنصات المفتوحة.',
                        style: TextStyle(
                          color: context.t.onSurface.withValues(alpha: 0.5),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Menu items
                _MenuTile(
                  icon: Icons.support_agent,
                  label: 'الدعم الفني',
                  onTap: () => context.push('/support'),
                ),
                const SizedBox(height: 8),
                _MenuTile(
                  icon: Icons.logout,
                  label: 'تسجيل الخروج',
                  color: context.t.error,
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: context.t.surface,
                        title: Text('تسجيل الخروج',
                            style:
                                TextStyle(color: context.t.onSurface)),
                        content: Text('هل تريد تسجيل الخروج؟',
                            style:
                                TextStyle(color: context.t.onSurface)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text('خروج',
                                style:
                                    TextStyle(color: context.t.error)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      final userId =
                          ref.read(supabaseProvider).auth.currentUser?.id;
                      if (userId != null) {
                        await SecureCredentials.clear(userId);
                      }
                      await ref.read(authServiceProvider).signOut();
                    }
                  },
                ),

                const SizedBox(height: 32),
                Text(
                  'Developed by Omar Sayed',
                  style: TextStyle(
                    color: context.t.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.t.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.t.onSurfaceVariant, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.t.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.t.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? context.t.onSurfaceVariant),
      title: Text(label,
          style: TextStyle(color: color ?? context.t.onSurface)),
      trailing: Icon(Icons.chevron_left,
          size: 18,
          color: color ?? context.t.onSurfaceVariant),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SolverTheme.radiusControl + 2),
      ),
      tileColor: context.t.surface,
      onTap: onTap,
    );
  }
}