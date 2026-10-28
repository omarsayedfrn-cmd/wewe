/// Support thread model matching `support_threads` DB table.
class SupportThread {
  final String id;
  final String userId;
  final String status;
  final DateTime? lastMessageAt;
  final int unreadAdmin;
  final int unreadUser;
  final DateTime createdAt;
  // Joined fields
  final String? lastMessageBody;
  final String? userDisplayName;

  const SupportThread({
    required this.id,
    required this.userId,
    this.status = 'open',
    this.lastMessageAt,
    this.unreadAdmin = 0,
    this.unreadUser = 0,
    required this.createdAt,
    this.lastMessageBody,
    this.userDisplayName,
  });

  factory SupportThread.fromJson(Map<String, dynamic> json) => SupportThread(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        status: json['status'] as String? ?? 'open',
        lastMessageAt: json['last_message_at'] != null
            ? DateTime.parse(json['last_message_at'] as String)
            : null,
        unreadAdmin: json['unread_admin'] as int? ?? 0,
        unreadUser: json['unread_user'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        lastMessageBody: json['last_message_body'] as String?,
        userDisplayName: json['user_display_name'] as String?,
      );

  bool get isOpen => status == 'open';
}

/// Support message model matching `support_messages` DB table.
class SupportMessage {
  final String id;
  final String threadId;
  final String senderRole; // 'user' | 'admin'
  final String body;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.threadId,
    required this.senderRole,
    required this.body,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
        id: json['id'] as String,
        threadId: json['thread_id'] as String,
        senderRole: json['sender_role'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  bool get isUser => senderRole == 'user';
  bool get isAdmin => senderRole == 'admin';
}
