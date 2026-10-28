import 'profile.dart';

/// Trial configuration resolved from the student's profile + dashboard settings.
class TrialInfo {
  final String engineCode;
  final int chapters;
  final bool claimed;
  final bool used;

  const TrialInfo({
    required this.engineCode,
    required this.chapters,
    required this.claimed,
    required this.used,
  });

  bool get available => chapters > 0 && (claimed || !used);

  bool appliesTo(String code) => engineCode == code;
}

/// Engine that gets the free trial for this student.
String? trialEngineFor(Profile profile) {
  if (profile.grade == 'grade_1') {
    return profile.language == 'ar' ? 'qureo' : 'qureo_js_en';
  }
  if (profile.grade == 'grade_2') {
    if (profile.track == 'engineering') {
      return profile.language == 'ar' ? 'qureo' : 'qureo_js_en';
    }
    return profile.language == 'ar' ? 'sprix' : 'sprix_en';
  }
  return null;
}

/// Dashboard setting key that holds the trial chapter count.
String? trialSettingKeyFor(Profile profile) {
  if (profile.grade == 'grade_1') return 'trial_chapters_grade1';
  if (profile.grade == 'grade_2') {
    if (profile.track == 'engineering') {
      return 'trial_chapters_grade2_engineering';
    }
    return 'trial_chapters_grade2_other';
  }
  return null;
}