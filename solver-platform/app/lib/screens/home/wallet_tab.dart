import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/error_view.dart';

/// Wallet tab — balance display and transaction history.
class WalletTab extends ConsumerWidget {
  const WalletTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);
    final txAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المحفظة')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Balance card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [SolverTheme.burgundy, SolverTheme.burgundyDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: SolverTheme.burgundy.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'الرصيد الحالي',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  walletAsync.when(
                    loading: () => const CircularProgressIndicator(
                        color: SolverTheme.gold, strokeWidth: 2),
                    error: (e, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'تعذر تحميل الرصيد',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref.invalidate(walletProvider),
                          child: const Text(
                            'إعادة المحاولة',
                            style: TextStyle(color: SolverTheme.gold),
                          ),
                        ),
                      ],
                    ),
                    data: (wallet) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${wallet.balance}',
                          style: const TextStyle(
                            color: SolverTheme.gold,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'عملة',
                          style: TextStyle(
                            color: SolverTheme.gold.withValues(alpha: 0.7),
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.white70, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'تواصل مع الدعم للشحن',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Transaction history header
            Row(
              children: [
                const Text(
                  'سجل العمليات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: SolverTheme.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => ref.invalidate(transactionsProvider),
                  child: const Text('تحديث',
                      style: TextStyle(color: SolverTheme.gold)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Transactions list
            Expanded(
              child: txAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: SolverTheme.gold, strokeWidth: 2),
                ),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(transactionsProvider),
                ),
                data: (txs) {
                  if (txs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long,
                              color: SolverTheme.onSurface
                                  .withValues(alpha: 0.3),
                              size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد عمليات بعد',
                            style: TextStyle(
                              color: SolverTheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: txs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: SolverTheme.surfaceVariant),
                    itemBuilder: (context, index) {
                      final tx = txs[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: tx.isCredit
                              ? SolverTheme.success.withValues(alpha: 0.2)
                              : SolverTheme.error.withValues(alpha: 0.2),
                          child: Icon(
                            tx.isCredit
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: tx.isCredit
                                ? SolverTheme.success
                                : SolverTheme.error,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          tx.reasonLabel,
                          style: const TextStyle(
                              color: SolverTheme.onSurface, fontSize: 15),
                        ),
                        subtitle: Text(
                          _formatDate(tx.createdAt),
                          style: TextStyle(
                            color: SolverTheme.onSurface
                                .withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                        trailing: Text(
                          '${tx.isCredit ? "+" : ""}${tx.delta}',
                          style: TextStyle(
                            color: tx.isCredit
                                ? SolverTheme.success
                                : SolverTheme.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
