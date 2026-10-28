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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(myEnginesProvider),
        ),
        data: (engines) {
          if (engines.isEmpty) {
            return Center(
              child: Text(
                'لا توجد محركات متاحة',
                style: TextStyle(color: context.t.onSurfaceVariant),
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
                    color: context.t.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${engines.length} محرك',
                  style: TextStyle(
                    color: context.t.onSurface.withValues(alpha: 0.6),
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
                            color: context.t.surface,
                            borderRadius: BorderRadius.circular(
                                SolverTheme.radiusCard),
                            border: Border.all(color: context.t.line),
                          ),
                          child: Row(
                            children: [
                              // Engine icon
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: context.t.burgundy
                                      .withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Center(
                                  child: Icon(
                                    engine.icon,
                                    size: 26,
                                    color: context.t.burgundy,
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
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: context.t.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${engine.maxChapter} فصل · ${engine.platformLabel}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: context.t.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_back_ios,
                                color: context.t.onSurfaceVariant,
                                size: 16,
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