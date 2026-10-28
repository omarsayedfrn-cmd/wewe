import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/engine_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/error_view.dart';

/// Engines tab — shows available engines for the user.
class EnginesTab extends ConsumerWidget {
  const EnginesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enginesAsync = ref.watch(myEnginesProvider);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المحركات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent),
            tooltip: 'الدعم',
            onPressed: () => context.push('/support'),
          ),
        ],
      ),
      body: enginesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: SolverTheme.gold),
        ),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(myEnginesProvider),
        ),
        data: (engines) {
          if (engines.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد محركات متاحة',
                style: TextStyle(color: SolverTheme.onSurfaceVariant),
              ),
            );
          }

          final lang = profile.valueOrNull?.language ?? 'ar';

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المحركات المتاحة',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: SolverTheme.gold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${engines.length} محرك',
                  style: TextStyle(
                    color: SolverTheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.separated(
                    itemCount: engines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final engine = engines[index];
                      return GestureDetector(
                        onTap: () =>
                            context.push('/engine/${engine.code}'),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: SolverTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: SolverTheme.surfaceVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Engine icon
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: SolverTheme.burgundy
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    engine.icon,
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Engine info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      engine.displayName(lang),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: SolverTheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${engine.maxChapter} فصل • ${engine.platform.toUpperCase()}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: SolverTheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: SolverTheme.gold,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
