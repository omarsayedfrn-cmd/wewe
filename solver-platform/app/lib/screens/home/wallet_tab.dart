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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.t.surface,
                borderRadius: BorderRadius.circular(SolverTheme.radiusCard),
                border: Border.all(color: context.t.line),
              ),
              child: Column(
                children: [
                  Text(
                    'الرصيد الحالي',
                    style: TextStyle(
                      color: context.t.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  walletAsync.when(
                    loading: () => CircularProgressIndicator(
                        color: context.t.burgundy, strokeWidth: 2),
                    error: (e, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'تعذر تحميل الرصيد',
                          style: TextStyle(
                            color: context.t.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref.invalidate(walletProvider),
                          child: const Text('إعادة المحاولة'),
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
                          style: TextStyle(
                            color: context.t.burgundy,
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'عملة',
                          style: TextStyle(
                            color: context.t.gold,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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
                      color: context.t.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(SolverTheme.radiusControl),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline,
                            color: context.t.onSurfaceVariant, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'الشحن عن طريق الدعم الفني',
                          style: TextStyle(
                              color: context.t.onSurfaceVariant,
                              fontSize: 13),
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
                Text(
                  'سجل العمليات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.t.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => ref.invalidate(transactionsProvider),
                  child: const Text('تحديث'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Transactions list
            Expanded(
              child: txAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
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
                              color: context.t.onSurface
                                  .withValues(alpha: 0.3),
                              size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد عمليات بعد',
                            style: TextStyle(
                              color: context.t.onSurface
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
                        Divider(color: context.t.surfaceVariant),
                    itemBuilder: (context, index) {
                      final tx = txs[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: tx.isCredit
                              ? context.t.success.withValues(alpha: 0.2)
                              : context.t.error.withValues(alpha: 0.2),
                          child: Icon(
                            tx.isCredit
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: tx.isCredit
                                ? context.t.success
                                : context.t.error,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          tx.reasonLabel,
                          style: TextStyle(
                              color: context.t.onSurface, fontSize: 15),
                        ),
                        subtitle: Text(
                          _formatDate(tx.createdAt),
                          style: TextStyle(
                            color: context.t.onSurface
                                .withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                        trailing: Text(
                          '${tx.isCredit ? "+" : ""}${tx.delta}',
                          style: TextStyle(
                            color: tx.isCredit
                                ? context.t.success
                                : context.t.error,
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