/// Answer models shared by the QUREO and SPRIX solvers.
///
/// The answer bank itself is NOT shipped inside the app anymore. It is fetched
/// from the `solver-answers` Edge Function after the server verifies the
/// caller's entitlement (see `lib/services/answers_service.dart`).
library;

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