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
        createdAt: createdAt,
      );

  bool get isStudent => role == 'student';
  bool get isMerchant => role == 'merchant';
  bool get isAdmin => role == 'admin';
  bool get needsOnboarding => !onboardLocked;
}
