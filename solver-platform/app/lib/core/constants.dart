/// App-wide constants for the Solver Platform.
library;

import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  // ── Supabase ──────────────────────────────────────────────────────────
  static const String supabaseUrl = 'https://sjelihyjbptoktpfdchy.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNqZWxpaHlqYnB0b2t0cGZkY2h5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMxNzE5NzUsImV4cCI6MjEwODc0Nzk3NX0.rSWuUJkEtGh3S-jtLSVusN-_owr7Ozxcaw2UBXo9EVA';

  // ── Google Sign-In ────────────────────────────────────────────────────
  static const String googleWebClientId = '663520357873-tv6vqt954nh0ps8ar5lhtre616vt347h.apps.googleusercontent.com';

  // ── Support / WhatsApp ────────────────────────────────────────────────
  static const String adminWhatsAppNumber = '201016890333'; // رقم الواتساب الخاص بالإدارة للتفعيل والمراجعة

  // ── Grades ────────────────────────────────────────────────────────────
  static const String grade1 = 'grade_1';
  static const String grade2 = 'grade_2';

  static const Map<String, String> gradeLabels = {
    grade1: 'أولى ثانوي',
    grade2: 'تانية ثانوي',
  };

  // ── Tracks (grade_2 only) ─────────────────────────────────────────────
  static const String trackMedicine = 'medicine';
  static const String trackBusiness = 'business';
  static const String trackArts = 'arts';
  static const String trackEngineering = 'engineering';

  static const Map<String, String> trackLabels = {
    trackMedicine: 'الطب والعلوم الحيوية',
    trackBusiness: 'إدارة الأعمال',
    trackArts: 'الآداب والفنون',
    trackEngineering: 'الهندسة وعلوم الحاسب',
  };

  static const Map<String, IconData> trackIcons = {
    trackMedicine: Icons.biotech_outlined,
    trackBusiness: Icons.query_stats,
    trackArts: Icons.palette_outlined,
    trackEngineering: Icons.engineering_outlined,
  };

  // ── Languages ─────────────────────────────────────────────────────────
  static const String langAr = 'ar';
  static const String langEn = 'en';

  static const Map<String, String> languageLabels = {
    langAr: 'عام',
    langEn: 'لغات',
  };

  // ── Engine Codes ──────────────────────────────────────────────────────
  static const String engineQureo = 'qureo';
  static const String engineQureoJsEn = 'qureo_js_en';
  static const String engineQureo2 = 'qureo2';
  static const String engineQureo2En = 'qureo2_en';
  static const String engineSprix = 'sprix';
  static const String engineSprixEn = 'sprix_en';

  static const Map<String, String> engineLabels = {
    engineQureo: 'QUREO جافاسكريبت',
    engineQureoJsEn: 'QUREO JavaScript EN',
    engineQureo2: 'QUREO2 بايثون',
    engineQureo2En: 'QUREO2 Python EN',
    engineSprix: 'SPRIX الثقافة المالية',
    engineSprixEn: 'SPRIX Financial Literacy',
  };

  /// Display-name overrides (كريو + language in parentheses).
  static const Map<String, String> engineArNameOverrides = {
    engineQureo: 'كريو (جافاسكربت)',
    engineQureo2: 'كريو (بايثون)',
  };

  static const Map<String, IconData> engineIcons = {
    engineQureo: Icons.code_outlined,
    engineQureoJsEn: Icons.code_outlined,
    engineQureo2: Icons.terminal_outlined,
    engineQureo2En: Icons.terminal_outlined,
    engineSprix: Icons.savings_outlined,
    engineSprixEn: Icons.savings_outlined,
  };

  /// Returns the list of engine codes available for a given grade/track/language.
  static List<String> enginesForStudent({
    required String grade,
    String? track,
    required String language,
  }) {
    final isAr = language == langAr;
    final engines = <String>[];

    if (grade == grade1) {
      // أولى ثانوي: QUREO فقط (42 فصل)
      engines.add(isAr ? engineQureo : engineQureoJsEn);
    } else if (grade == grade2) {
      if (track == trackEngineering) {
        // هندسة وحاسب: SPRIX + QUREO (54) + QUREO2
        engines.add(isAr ? engineSprix : engineSprixEn);
        engines.add(isAr ? engineQureo : engineQureoJsEn);
        engines.add(isAr ? engineQureo2 : engineQureo2En);
      } else {
        // باقي المسارات: SPRIX فقط
        engines.add(isAr ? engineSprix : engineSprixEn);
      }
    }

    return engines;
  }

  // ── Max Parallel Solve Sessions ───────────────────────────────────────
  static const int maxParallelSessions = 3;
}
