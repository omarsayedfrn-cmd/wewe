import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/support_provider.dart';
import '../../widgets/error_view.dart';

/// Support threads list screen.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(supportThreadsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الدعم الفني')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          try {
            final thread = await ref
                .read(supportServiceProvider)
                .getOrCreateThread();
            if (context.mounted) {
              context.push('/support/${thread.id}');
            }
          } catch (e) {
            if (context.mounted) {
              showErrorSnack(context, e, action: 'بدء محادثة دعم');
            }
          }
        },
        backgroundColor: context.t.burgundy,
        icon: const Icon(Icons.add),
        label: const Text('محادثة جديدة'),
      ),
      body: threadsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(supportThreadsProvider),
        ),
        data: (threads) {
          if (threads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.support_agent,
                      size: 64,
                      color: context.t.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد محادثات بعد',
                    style: TextStyle(
                      color: context.t.onSurface.withValues(alpha: 0.5),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اضغط + لبدء محادثة مع فريق الدعم',
                    style: TextStyle(
                      color: context.t.onSurface.withValues(alpha: 0.3),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: threads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final thread = threads[index];
              return ListTile(
                tileColor: context.t.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: CircleAvatar(
                  backgroundColor: thread.isOpen
                      ? context.t.success.withValues(alpha: 0.2)
                      : context.t.surfaceVariant,
                  child: Icon(
                    thread.isOpen ? Icons.chat : Icons.chat_outlined,
                    color: thread.isOpen
                        ? context.t.success
                        : context.t.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                title: Text(
                  thread.isOpen ? 'محادثة مفتوحة' : 'محادثة مغلقة',
                  style: TextStyle(
                      color: context.t.onSurface, fontSize: 15),
                ),
                subtitle: Text(
                  thread.lastMessageAt != null
                      ? _formatDate(thread.lastMessageAt!)
                      : _formatDate(thread.createdAt),
                  style: TextStyle(
                    color: context.t.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                trailing: thread.unreadUser > 0
                    ? CircleAvatar(
                        radius: 12,
                        backgroundColor: context.t.burgundy,
                        child: Text(
                          '${thread.unreadUser}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                      )
                    : Icon(Icons.chevron_left,
                        size: 18, color: context.t.onSurfaceVariant),
                onTap: () => context.push('/support/${thread.id}'),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}