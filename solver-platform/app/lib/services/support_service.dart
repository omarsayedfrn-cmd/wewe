import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/support_thread.dart';

/// Service for support chat (uses Supabase Realtime).
class SupportService {
  final SupabaseClient _client;

  SupportService(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// Get or create a support thread for the current user.
  Future<SupportThread> getOrCreateThread() async {
    // Try to find existing open thread
    final existing = await _client
        .from('support_threads')
        .select()
        .eq('user_id', _userId)
        .eq('status', 'open')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existing != null) return SupportThread.fromJson(existing);

    // Create new thread
    final data = await _client.from('support_threads').insert({
      'user_id': _userId,
      'status': 'open',
    }).select().single();
    return SupportThread.fromJson(data);
  }

  /// Get all threads for the current user.
  Future<List<SupportThread>> getMyThreads() async {
    final data = await _client
        .from('support_threads')
        .select()
        .eq('user_id', _userId)
        .order('last_message_at', ascending: false);
    return data.map((e) => SupportThread.fromJson(e)).toList();
  }

  /// Get messages for a thread.
  Future<List<SupportMessage>> getMessages(String threadId) async {
    final data = await _client
        .from('support_messages')
        .select()
        .eq('thread_id', threadId)
        .order('created_at');
    return data.map((e) => SupportMessage.fromJson(e)).toList();
  }

  /// Send a message in a thread.
  ///
  /// Thread metadata (last_message_at / unread counters) is maintained by a
  /// database trigger, so the client only inserts the message itself. Updating
  /// support_threads from a student client is blocked by RLS anyway.
  Future<SupportMessage> sendMessage(String threadId, String body) async {
    final data = await _client.from('support_messages').insert({
      'thread_id': threadId,
      'sender_role': 'user',
      'body': body,
    }).select().single();

    return SupportMessage.fromJson(data);
  }

  /// Subscribe to real-time messages in a thread.
  RealtimeChannel subscribeToMessages(
      String threadId, void Function(SupportMessage) onMessage) {
    return _client
        .channel('support_messages:$threadId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'support_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: threadId,
          ),
          callback: (payload) {
            onMessage(SupportMessage.fromJson(payload.newRecord));
          },
        )
        .subscribe();
  }

  /// Mark thread as read for user.
  ///
  /// Students cannot UPDATE support_threads directly (RLS), so this goes
  /// through a SECURITY DEFINER RPC that only touches the caller's thread.
  Future<void> markAsRead(String threadId) async {
    try {
      await _client.rpc('mark_support_thread_read', params: {
        'p_thread_id': threadId,
      });
    } catch (e) {
      debugPrint('[Support] mark read skipped: $e');
    }
  }
}
