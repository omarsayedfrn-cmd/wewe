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

  /// Platform account (normalized login) this entitlement belongs to.
  /// Null until the student's account is bound (first solve).
  final String? platformLoginNorm;

  const Entitlement({
    required this.id,
    required this.userId,
    required this.engineCode,
    required this.scope,
    this.chapters = const [],
    required this.source,
    required this.createdAt,
    this.expiresAt,
    this.platformLoginNorm,
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
        platformLoginNorm: json['platform_login_norm'] as String?,
      );

  bool get isFull => scope == 'full';
  bool get isTrial => source == 'trial';

  /// True when this entitlement may be used with the given bound account.
  ///
  /// An entitlement with no stamp yet (before the first solve) matches any
  /// account; once stamped it only matches its own account.
  bool matchesAccount(String? loginNorm) =>
      platformLoginNorm == null ||
      loginNorm == null ||
      platformLoginNorm == loginNorm;

  /// Check if a specific chapter number is entitled.
  bool hasChapter(int chapter) {
    if (isFull) return true;
    return chapters.contains(chapter);
  }
}
