import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/support_thread.dart';
import '../services/support_service.dart';
import 'auth_provider.dart';

/// Support service provider.
final supportServiceProvider = Provider<SupportService>((ref) {
  return SupportService(ref.watch(supabaseProvider));
});

/// User's support threads.
final supportThreadsProvider =
    FutureProvider<List<SupportThread>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(supportServiceProvider).getMyThreads();
});

/// Messages for a specific thread.
final threadMessagesProvider =
    FutureProvider.family<List<SupportMessage>, String>((ref, threadId) async {
  return ref.read(supportServiceProvider).getMessages(threadId);
});
