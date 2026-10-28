import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:encrypt/encrypt.dart';

typedef IdPair = (int, int);

class QChoice {
  final int qid;
  final String qtype;
  final int? choiceId;
  final String? answerCode;

  const QChoice({
    required this.qid,
    required this.qtype,
    this.choiceId,
    this.answerCode,
  });

  factory QChoice.fromJson(Map<String, dynamic> json) => QChoice(
        qid: json['qid'] as int,
        qtype: json['qtype'] as String,
        choiceId: json['choice_id'] as int?,
        answerCode: json['answer_code'] as String?,
      );
}

class QChapter {
  final String type;
  final List<QChoice> questions;

  const QChapter({
    required this.type,
    required this.questions,
  });

  factory QChapter.fromJson(Map<String, dynamic> json) {
    final qs = (json['questions'] as List<dynamic>?) ?? [];
    return QChapter(
      type: json['type'] as String? ?? 'review',
      questions: qs.map((q) => QChoice.fromJson(q as Map<String, dynamic>)).toList(),
    );
  }
}

class AnswersBundle {
  static const String _k1 = 'S0lv3r_Pl4tf0rm_';
  static const String _k2 = 'K3y_2026_Om4r!!!';

  static Map<String, dynamic>? _cachedBundle;

  static Future<Map<String, dynamic>> loadBundle() async {
    if (_cachedBundle != null) return _cachedBundle!;

    final data = await rootBundle.load('assets/answers.enc');
    final bytes = data.buffer.asUint8List();

    if (bytes.length < 16) {
      throw Exception('Invalid answers.enc asset size');
    }

    final ivBytes = bytes.sublist(0, 16);
    final cipherBytes = bytes.sublist(16);

    final key = Key.fromUtf8(_k1 + _k2);
    final iv = IV(ivBytes);

    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final decrypted = encrypter.decrypt(Encrypted(cipherBytes), iv: iv);

    _cachedBundle = jsonDecode(decrypted) as Map<String, dynamic>;
    return _cachedBundle!;
  }

  /// Get QUREO answers map (raw chapter id -> QChapter)
  static Future<Map<String, QChapter>> getQureo(String engineCode) async {
    final bundle = await loadBundle();
    final raw = (bundle[engineCode] as Map<String, dynamic>?) ?? {};
    final result = <String, QChapter>{};

    for (final entry in raw.entries) {
      result[entry.key] = QChapter.fromJson(entry.value as Map<String, dynamic>);
    }

    return result;
  }

  /// Get SPRIX chapters: chapterId -> list of (blockId, optionId)
  static Future<Map<String, List<IdPair>>> getSprixChapters(String engineCode) async {
    final bundle = await loadBundle();
    final raw = (bundle[engineCode] as Map<String, dynamic>?)?['chapters'] as Map<String, dynamic>? ?? {};
    final result = <String, List<IdPair>>{};

    for (final entry in raw.entries) {
      final list = entry.value as List<dynamic>;
      result[entry.key] = list.map((item) {
        final pair = item as List<dynamic>;
        return (pair[0] as int, pair[1] as int);
      }).toList();
    }

    return result;
  }

  /// Get SPRIX tests: testId -> list of (questionId, optionId)
  static Future<Map<String, List<IdPair>>> getSprixTests(String engineCode) async {
    final bundle = await loadBundle();
    final raw = (bundle[engineCode] as Map<String, dynamic>?)?['tests'] as Map<String, dynamic>? ?? {};
    final result = <String, List<IdPair>>{};

    for (final entry in raw.entries) {
      final list = entry.value as List<dynamic>;
      result[entry.key] = list.map((item) {
        final pair = item as List<dynamic>;
        return (pair[0] as int, pair[1] as int);
      }).toList();
    }

    return result;
  }
}
