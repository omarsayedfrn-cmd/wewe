/// Entitlement model matching the `entitlements` DB table.
class Entitlement {
  final String id;
  final String userId;
  final String engineCode;
  final String scope; // 'full' | 'chapter'
  final List<int> chapters;
  final String source; // 'trial' | 'purchase' | 'gift'
  final DateTime createdAt;
  final DateTime? expiresAt;

  const Entitlement({
    required this.id,
    required this.userId,
    required this.engineCode,
    required this.scope,
    this.chapters = const [],
    required this.source,
    required this.createdAt,
    this.expiresAt,
  });

  factory Entitlement.fromJson(Map<String, dynamic> json) => Entitlement(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        engineCode: json['engine_code'] as String,
        scope: json['scope'] as String,
        chapters: (json['chapters'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            [],
        source: json['source'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'] as String)
            : null,
      );

  bool get isFull => scope == 'full';
  bool get isTrial => source == 'trial';

  /// Check if a specific chapter number is entitled.
  bool hasChapter(int chapter) {
    if (isFull) return true;
    return chapters.contains(chapter);
  }
}
