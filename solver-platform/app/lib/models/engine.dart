/// Engine model matching the `engines` DB table.
class Engine {
  final String code;
  final String nameAr;
  final String nameEn;
  final String platform; // 'qureo' or 'sprix'
  final String course;
  final String language; // 'ar' or 'en'
  final int maxChapter;

  const Engine({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.platform,
    required this.course,
    required this.language,
    required this.maxChapter,
  });

  factory Engine.fromJson(Map<String, dynamic> json) => Engine(
        code: json['code'] as String,
        nameAr: json['name_ar'] as String,
        nameEn: json['name_en'] as String,
        platform: json['platform'] as String,
        course: json['course'] as String,
        language: json['language'] as String,
        maxChapter: json['max_chapter'] as int,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name_ar': nameAr,
        'name_en': nameEn,
        'platform': platform,
        'course': course,
        'language': language,
        'max_chapter': maxChapter,
      };

  /// Returns localized name based on app language.
  String displayName(String lang) => lang == 'ar' ? nameAr : nameEn;

  /// Icon emoji for this engine.
  String get icon {
    if (platform == 'qureo') {
      return course.contains('python') ? '🐍' : '💻';
    }
    return '💰';
  }
}
