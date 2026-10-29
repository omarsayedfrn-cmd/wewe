/// User profile model matching the `profiles` DB table.
class Profile {
  final String id;
  final String role;
  final String? grade;
  final String? track;
  final String language;
  final String? displayName;
  final String? avatar;
  final String referralCode;
  final String? referredBy;
  final bool trialUsed;
  final bool onboardLocked;

  /// Whether an admin has approved this account. New accounts start locked to
  /// prevent spam. Defaults to true when the column is absent (older backend).
  final bool approved;
  final DateTime? approvedAt;

  /// Platform account (student login code) bound to this profile. Shared across
  /// every engine the student owns; set on the first solve and then locked.
  final String? platformLogin;
  final DateTime? platformBoundAt;
  final DateTime createdAt;

  const Profile({
    required this.id,
    this.role = 'student',
    this.grade,
    this.track,
    this.language = 'ar',
    this.displayName,
    this.avatar,
    required this.referralCode,
    this.referredBy,
    this.trialUsed = false,
    this.onboardLocked = false,
    this.approved = true,
    this.approvedAt,
    this.platformLogin,
    this.platformBoundAt,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        role: json['role'] as String? ?? 'student',
        grade: json['grade'] as String?,
        track: json['track'] as String?,
        language: json['language'] as String? ?? 'ar',
        displayName: json['display_name'] as String?,
        avatar: json['avatar'] as String?,
        referralCode: json['referral_code'] as String? ?? '',
        referredBy: json['referred_by'] as String?,
        trialUsed: json['trial_used'] as bool? ?? false,
        onboardLocked: json['onboard_locked'] as bool? ?? false,
        approved: json['approved'] as bool? ?? true,
        approvedAt: json['approved_at'] != null
            ? DateTime.tryParse(json['approved_at'] as String)
            : null,
        platformLogin: json['platform_login'] as String?,
        platformBoundAt: json['platform_bound_at'] != null
            ? DateTime.tryParse(json['platform_bound_at'] as String)
            : null,
        createdAt: DateTime.parse(
            json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        if (grade != null) 'grade': grade,
        if (track != null) 'track': track,
        'language': language,
        if (displayName != null) 'display_name': displayName,
        if (avatar != null) 'avatar': avatar,
        if (referredBy != null) 'referred_by': referredBy,
        'trial_used': trialUsed,
        'onboard_locked': onboardLocked,
        'approved': approved,
        if (approvedAt != null) 'approved_at': approvedAt!.toIso8601String(),
        if (platformLogin != null) 'platform_login': platformLogin,
        if (platformBoundAt != null)
          'platform_bound_at': platformBoundAt!.toIso8601String(),
      };

  Profile copyWith({
    String? role,
    String? grade,
    String? track,
    String? language,
    String? displayName,
    String? avatar,
    String? referralCode,
    String? referredBy,
    bool? trialUsed,
    bool? onboardLocked,
    bool? approved,
    DateTime? approvedAt,
    String? platformLogin,
    DateTime? platformBoundAt,
  }) =>
      Profile(
        id: id,
        role: role ?? this.role,
        grade: grade ?? this.grade,
        track: track ?? this.track,
        language: language ?? this.language,
        displayName: displayName ?? this.displayName,
        avatar: avatar ?? this.avatar,
        referralCode: referralCode ?? this.referralCode,
        referredBy: referredBy ?? this.referredBy,
        trialUsed: trialUsed ?? this.trialUsed,
        onboardLocked: onboardLocked ?? this.onboardLocked,
        approved: approved ?? this.approved,
        approvedAt: approvedAt ?? this.approvedAt,
        platformLogin: platformLogin ?? this.platformLogin,
        platformBoundAt: platformBoundAt ?? this.platformBoundAt,
        createdAt: createdAt,
      );

  bool get isStudent => role == 'student';
  bool get isMerchant => role == 'merchant';
  bool get isAdmin => role == 'admin';
  bool get needsOnboarding => !onboardLocked;

  /// True when the account may use the app. Non-students (admins/merchants)
  /// are always allowed so they can never be locked out.
  bool get isApproved => approved || role != 'student';

  /// True once a platform account has been bound to this profile.
  bool get hasBoundAccount =>
      platformLogin != null && platformLogin!.trim().isNotEmpty;

  /// Normalized bound account (lowercase, trimmed) or null when unbound.
  String? get platformLoginNorm {
    final login = platformLogin?.trim().toLowerCase();
    return (login == null || login.isEmpty) ? null : login;
  }
}
