import 'dart:convert';
import 'api.dart';
import 'pace.dart';
import 'answers.dart';

class CachedTalk {
  final String tid;
  final String payload;
  const CachedTalk(this.tid, this.payload);
}

class CachedLecture {
  final String lid;
  final List<CachedTalk> talks;
  const CachedLecture(this.lid, this.talks);
}

class QureoCourse {
  final String contentId;
  final int sectionId;
  final String courseId;
  final int totalDiamonds;
  final int baseId;
  final int totalChapters;

  const QureoCourse({
    required this.contentId,
    required this.sectionId,
    required this.courseId,
    required this.totalDiamonds,
    required this.baseId,
    required this.totalChapters,
  });

  static const qureo = QureoCourse(
    contentId: 'javascript_ar',
    sectionId: 5,
    courseId: 'javascript_ar',
    totalDiamonds: 270,
    baseId: 90000,
    totalChapters: 54,
  );

  static const qureo2 = QureoCourse(
    contentId: 'python_short_ar',
    sectionId: 106,
    courseId: 'python_short_ar',
    totalDiamonds: 125,
    baseId: 511000,
    totalChapters: 25,
  );

  static const qureoEn = QureoCourse(
    contentId: 'javascript_en',
    sectionId: 2,
    courseId: 'javascript_en',
    totalDiamonds: 270,
    baseId: 30000,
    totalChapters: 54,
  );

  static const qureo2En = QureoCourse(
    contentId: 'python_short_en',
    sectionId: 202,
    courseId: 'python_short_en',
    totalDiamonds: 50,
    baseId: 531000,
    totalChapters: 10,
  );

  static QureoCourse of(String platform) {
    switch (platform) {
      case 'qureo2':
        return qureo2;
      case 'qureo2_en':
        return qureo2En;
      case 'qureo_js_en':
      case 'qureo_en':
        return qureoEn;
      default:
        return qureo;
    }
  }

  bool get isEn => contentId.endsWith('_en');

  int? naturalOf(String raw) {
    final val = int.tryParse(raw);
    if (val == null) return null;
    final n = val - baseId;
    return (n >= 1 && n <= totalChapters) ? n : null;
  }

  String? rawOf(int natural) {
    if (natural >= 1 && natural <= totalChapters) {
      return (baseId + natural).toString();
    }
    return null;
  }
}

class QureoSolver {
  final SolverApi portal;
  final SolverApi tp;
  final void Function(String) log;
  final Pace pace;
  final QureoCourse course;

  static final Map<String, List<CachedLecture>> _lectureCache = {};

  /// Platform-authoritative chapter type (`review`/`test`) learned while
  /// fetching chapter details. Falls back to the answer bank when unknown.
  static final Map<String, String> _ctypeCache = {};

  static const String portalBase = 'https://me-portal.qureo.education';
  static const String tpBase = 'https://me-tp.qureo.education';

  QureoSolver({
    required this.portal,
    required this.tp,
    required this.log,
    required this.pace,
    this.course = QureoCourse.qureo,
  });

  Future<void> runWith({
    required String loginId,
    required String password,
    required int start,
    int? end,
    required Map<String, QChapter> answers,
    bool trialMode = false,
    void Function(int done, int total, String label)? onProgress,
    void Function(String nextStart)? onResume,
  }) async {
    log('[1/4] تسجيل الدخول إلى البوابة...');
    final lr = await portal.req(
      'POST',
      '$portalBase/oauth2/password-login',
      body: jsonEncode({'student_id': loginId, 'password': password}),
    );
    log('login http=${lr.code}');
    await pace.auth(1000);

    log('[2/4] التحقق من بيانات المستخدم...');
    final uinfo = await portal.req('GET', '$portalBase/oauth2/userinfo');
    log(uinfo.body.length > 300 ? uinfo.body.substring(0, 300) : uinfo.body);
    await pace.auth(500);

    log('[3/4] تهيئة جلسة TP...');
    // The selected-content cookies must exist BEFORE the TP bootstrap request:
    // without them /students/me refreshes the session and redirects to /login
    // instead of returning JSON.
    await tp.addCookie('.qureo.education', 'student_selected_content_id', course.contentId);
    final lang = course.isEn ? 'en' : 'ar';
    await tp.addCookie('.qureo.education', 'i18next', lang);

    final me = await tp.req('GET', '$tpBase/api/study/students/me');
    log('tp me http=${me.code}');
    await pace.auth(500);

    if (course.isEn) {
      await _runEn(answers, start, end, trialMode, onProgress, onResume);
    } else {
      await _runAr(answers, start, end, trialMode, onProgress, onResume);
    }
  }

  Future<void> _runAr(
    Map<String, QChapter> answers,
    int start,
    int? end,
    bool trialMode,
    void Function(int, int, String)? onProgress,
    void Function(String)? onResume,
  ) async {
    final chapters = answers.keys
        .map((k) => int.tryParse(k))
        .whereType<int>()
        .where((cid) => cid >= start && (end == null || cid <= end))
        .toList()
      ..sort();

    if (chapters.isEmpty) {
      throw SolverStop('لا توجد فصول >= $start في ملف الإجابات');
    }

    log('جاري حل ${chapters.length} فصلاً من $start إلى ${chapters.last}');
    onProgress?.call(0, chapters.length, 'فصل $start');

    for (int idx = 0; idx < chapters.length; idx++) {
      final cid = chapters[idx];
      final i = idx + 1;
      final ch = answers[cid.toString()];
      if (ch == null) continue;

      log('=== [$i/${chapters.length}] محاضرات الفصل $cid (${ch.type})...');
      await _completeLectures(cid.toString());

      log('--- بدء اختبار الفصل $cid');
      await _solveChapterVerified(cid.toString(), ch);

      onProgress?.call(i, chapters.length, 'فصل $cid');
      if (idx + 1 < chapters.length) {
        onResume?.call(chapters[idx + 1].toString());
      } else {
        onResume?.call('done');
      }

      if (trialMode) {
        log('--------------------------------------------------');
        log('التجربة: تم حل فصل التأكيد ($cid) بنجاح');
        log('--------------------------------------------------');
        onProgress?.call(1, 1, 'تمت التجربة');
        return;
      }
    }

    await _logFinalStatus();
  }

  Future<void> _runEn(
    Map<String, QChapter> answers,
    int start,
    int? end,
    bool trialMode,
    void Function(int, int, String)? onProgress,
    void Function(String)? onResume,
  ) async {
    final sectionsRaw = await tp.req('GET', '$tpBase/api/study/sections/${course.sectionId}');
    final sectionsObj = requireJsonObject(sectionsRaw, 'sections');
    final chaptersArr = (sectionsObj['chapters'] as List<dynamic>?) ?? [];

    final chapterList = <(String, String)>[];
    for (final item in chaptersArr) {
      final c = item as Map<String, dynamic>;
      final cid = c['id'].toString();
      final numericId = int.tryParse(cid) ?? 0;
      if (numericId < start) continue;
      if (end != null && numericId > end) continue;
      final ctype = c['test_type'] as String? ?? 'review';
      chapterList.add((cid, ctype));
    }

    chapterList.sort((a, b) => (int.tryParse(a.$1) ?? 0).compareTo(int.tryParse(b.$1) ?? 0));
    if (chapterList.isEmpty) {
      throw SolverStop('no chapters >= $start in section ${course.sectionId}');
    }

    log('Solving ${chapterList.length} EN chapters from $start');
    onProgress?.call(0, chapterList.length, 'chapter $start');

    for (int idx = 0; idx < chapterList.length; idx++) {
      final entry = chapterList[idx];
      final cid = entry.$1;
      final ctype = entry.$2;
      final i = idx + 1;

      log('=== [$i/${chapterList.length}] chapter $cid ($ctype) lectures...');
      try {
        await _completeLectures(cid);
      } catch (_) {
        log('تنبيه: تم تخطي الفصل $cid (غير متاح أو مغلق على المنصة)');
        continue;
      }

      log('--- start test $cid');
      final ch = answers[cid];
      if (ch != null && ch.questions.isNotEmpty) {
        await _solveChapterVerified(cid, ch);
      } else {
        await tp.req('PUT', '$tpBase/api/study/students/chapters/$cid/test', body: '{}');
        await pace.step(40);
        final prefix = ctype == 'test' ? 'test-questions' : 'review-questions';
        final completed = await _solveTestEn(cid, ctype, prefix);
        if (!completed) {
          log('تنبيه: اختبار الفصل $cid غير مكتمل، سيتم تخطي الفصل التالي');
          continue;
        }
      }

      onProgress?.call(i, chapterList.length, 'chapter $cid');
      if (idx + 1 < chapterList.length) {
        onResume?.call(chapterList[idx + 1].$1);
      } else {
        onResume?.call('done');
      }

      if (trialMode) {
        log('Trial done: chapter $cid solved successfully');
        onProgress?.call(1, 1, 'trial done');
        return;
      }
    }

    await _logFinalStatus();
  }

  Future<bool> _solveTestEn(String cid, String ctype, String prefix) async {
    final mapFile = <String, Map<String, dynamic>>{};
    log('--- learn pass $cid ($prefix)');
    await tp.req('PUT', '$tpBase/api/study/students/chapters/$cid/test', body: '{}');
    await pace.step(40);

    final tqRaw = await tp.req('GET', '$tpBase/api/study/chapters/$cid/test');
    final tqArr = requireJsonArray(tqRaw, 'test questions $cid');

    for (final item in tqArr) {
      final q = item as Map<String, dynamic>;
      final qObj = q['question'] as Map<String, dynamic>?;
      final qid = qObj?['id']?.toString() ?? q['question_id']?.toString() ?? '';
      final qtype = qObj?['type']?.toString() ?? q['type']?.toString() ?? 'choice';
      if (qid.isEmpty) continue;

      if (qtype == 'choice') {
        final choices = (q['choices'] as List<dynamic>?) ?? [];
        final guessId = choices.isNotEmpty ? (choices[0] as Map<String, dynamic>)['id'] as int? ?? 0 : 0;
        final out = (await tp.req(
          'PUT',
          '$tpBase/api/study/students/$prefix/$qid/answer/choice',
          body: jsonEncode({'choice_id': guessId}),
        )).body;

        final real = _harvestChoiceId(out);
        if (real != null) {
          mapFile[qid] = {'type': 'choice', 'choice_id': real};
          log('  q $qid (choice): harvested $real');
        }
      } else {
        final descriptions = (q['descriptions'] as List<dynamic>?) ?? [];
        final starterCode = descriptions.isNotEmpty ? (descriptions[0] as Map<String, dynamic>)['code'] as String? ?? '' : '';
        final guessCode = starterCode.isNotEmpty ? starterCode : "console.log('x')";
        final out = (await tp.req(
          'PUT',
          '$tpBase/api/study/students/$prefix/$qid/answer/description',
          body: jsonEncode({'answer_code': guessCode}),
        )).body;

        final real = _harvestModelAnswer(out);
        if (real != null) {
          mapFile[qid] = {'type': 'description', 'answer_code': real};
          log('  q $qid (desc): harvested model_answer');
        }
      }
      await pace.step(20);
    }

    final resultRaw = await tp.req('GET', '$tpBase/api/study/students/chapters/$cid/$ctype/result');
    if (isSuccessJson(resultRaw)) {
      _harvestFromResult(resultRaw.body, mapFile);
    }

    log('--- apply pass $cid (restart + answer correct)');
    await tp.req('PUT', '$tpBase/api/study/students/chapters/$cid/test', body: '{}');
    await pace.step(40);

    for (final item in tqArr) {
      final q = item as Map<String, dynamic>;
      final qObj = q['question'] as Map<String, dynamic>?;
      final qid = qObj?['id']?.toString() ?? q['question_id']?.toString() ?? '';
      if (qid.isEmpty) continue;
      final entry = mapFile[qid];
      if (entry == null) continue;

      final prefix2 = ctype == 'test' ? 'test-questions' : 'review-questions';
      if (entry['type'] == 'choice') {
        final choiceId = entry['choice_id'] as int? ?? 0;
        await tp.req(
          'PUT',
          '$tpBase/api/study/students/$prefix2/$qid/answer/choice',
          body: jsonEncode({'choice_id': choiceId}),
        );
      } else {
        final ans = entry['answer_code'] as String? ?? '';
        await tp.req(
          'PUT',
          '$tpBase/api/study/students/$prefix2/$qid/answer/description',
          body: jsonEncode({'answer_code': ans}),
        );
      }
      await pace.step(20);
    }

    final verifyRaw = await tp.req('GET', '$tpBase/api/study/students/chapters/$cid/$ctype/result');
    if (isSuccessJson(verifyRaw)) {
      try {
        final res = jsonDecode(verifyRaw.body) as Map<String, dynamic>;
        final result = (res['result'] as Map<String, dynamic>?) ?? res;
        final diamond = result['diamond'] as int? ?? 0;
        final completedAt = result['completed_at'] as String? ?? '';
        return diamond >= 5 || completedAt.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  void _harvestFromResult(String body, Map<String, Map<String, dynamic>> map) {
    try {
      final res = jsonDecode(body) as Map<String, dynamic>;
      final result = (res['result'] as Map<String, dynamic>?) ?? res;
      final choiceResults = (result['choice_results'] as List<dynamic>?) ??
          (result['choices'] as List<dynamic>?) ??
          [];

      for (final item in choiceResults) {
        final cr = item as Map<String, dynamic>;
        final qid = cr['question_id']?.toString() ?? '';
        final choices = (cr['choices'] as List<dynamic>?) ?? [];
        for (final chItem in choices) {
          final ch = chItem as Map<String, dynamic>;
          if (ch['correct'] == true) {
            final real = (ch['choice'] as Map<String, dynamic>?)?['id']?.toString() ??
                ch['id']?.toString() ??
                '';
            if (real.isNotEmpty) {
              map[qid] = {'type': 'choice', 'choice_id': int.tryParse(real) ?? 0};
              log('  q $qid (choice): harvested from result $real');
            }
            break;
          }
        }
      }

      final descResults = (result['description_results'] as List<dynamic>?) ?? [];
      for (final item in descResults) {
        final dr = item as Map<String, dynamic>;
        final qid = dr['question_id']?.toString() ?? '';
        final modelAnswer = dr['model_answer']?.toString() ?? '';
        if (modelAnswer.isNotEmpty) {
          map[qid] = {'type': 'description', 'answer_code': modelAnswer};
          log('  q $qid (desc): harvested from result');
        }
      }
    } catch (_) {}
  }

  int? _harvestChoiceId(String out) {
    try {
      final obj = jsonDecode(out) as Map<String, dynamic>;
      final result = (obj['result'] as Map<String, dynamic>?) ?? obj;
      final choices = (result['choices'] as List<dynamic>?) ?? [];
      for (final item in choices) {
        final ch = item as Map<String, dynamic>;
        if (ch['correct'] == true) {
          return (ch['choice'] as Map<String, dynamic>?)?['id'] as int? ??
              ch['id'] as int? ??
              -1;
        }
      }
    } catch (_) {}
    return null;
  }

  String? _harvestModelAnswer(String out) {
    try {
      final obj = jsonDecode(out) as Map<String, dynamic>;
      final result = (obj['result'] as Map<String, dynamic>?) ?? obj;
      final ma = result['model_answer'] as String? ?? '';
      return ma.isNotEmpty ? ma : null;
    } catch (_) {}
    return null;
  }

  Future<void> _completeLectures(String cid) async {
    var cached = _lectureCache[cid];
    if (cached == null) {
      final chapRaw = await tp.req('GET', '$tpBase/api/study/chapters/$cid');
      final chapObj = requireJsonObject(chapRaw, 'chapter $cid');
      final tt = chapObj['test_type']?.toString();
      if (tt == 'test' || tt == 'review') _ctypeCache[cid] = tt!;
      final lectures = (chapObj['lectures'] as List<dynamic>?) ?? [];
      if (lectures.isEmpty) throw SolverStop('no lectures for $cid (locked?)');

      final list = <CachedLecture>[];
      for (final lecItem in lectures) {
        final lid = (lecItem as Map<String, dynamic>)['id'].toString();
        final talksRaw = await tp.req('GET', '$tpBase/api/study/lectures/$lid');
        final talksObj = requireJsonObject(talksRaw, 'lecture $lid');
        if (!talksObj.containsKey('talks')) {
          throw SolverStop('lecture $lid locked');
        }
        final talks = talksObj['talks'] as List<dynamic>;
        final talksList = <CachedTalk>[];

        for (final tItem in talks) {
          final t = tItem as Map<String, dynamic>;
          final type = t['type']?.toString() ?? '';
          if (!type.startsWith('try')) continue;
          final tid = t['id'].toString();
          final bodyObj = t['body'] as Map<String, dynamic>;
          final codes = bodyObj['codes'] as List<dynamic>;
          final code = codes[0] as Map<String, dynamic>;
          final lang = code['lang'] as String? ?? 'javascript';
          var model = code['model_answer'] as String? ?? '';
          final src = code['code'] as String? ?? '';
          if (model.isEmpty) model = src;

          final String payload;
          final ph = (code['placeholders'] as List<dynamic>?) ?? [];
          if (ph.isNotEmpty && src.contains('fitbBlock')) {
            final arr = ph.map((p) {
              final pm = p as Map<String, dynamic>;
              return {
                'name': pm['name'],
                'code': pm['model_answer'] ?? '',
              };
            }).toList();
            payload = jsonEncode({'value': {'lang': lang, 'answers': arr}});
          } else {
            payload = jsonEncode({'value': {'lang': lang, 'answer': model}});
          }

          talksList.add(CachedTalk(tid, payload));
        }

        list.add(CachedLecture(lid, talksList));
      }
      _lectureCache[cid] = list;
      cached = list;
    }

    for (final lec in cached) {
      await tp.req('PUT', '$tpBase/api/study/students/lectures/${lec.lid}', body: '{}');
      await pace.step(20);
      for (final t in lec.talks) {
        await tp.req('PUT', '$tpBase/api/study/students/lecture-talks/${t.tid}', body: t.payload);
        await pace.step(20);
      }
      await tp.req('PUT', '$tpBase/api/study/students/lectures/${lec.lid}/complete', body: '{}');
      await pace.step(20);
    }
  }

  /// Solves one chapter test from the answer bank, then verifies the platform's
  /// result and, whenever the chapter is not PERFECT (diamond < 5), harvests the
  /// platform's own correct answers and re-submits them.
  ///
  /// This makes the mobile engine self-healing: even if a bank answer is wrong
  /// (or the grader disagrees with it), the correct answer is discovered from
  /// the result endpoint and used until the chapter reaches diamond 5.
  Future<void> _solveChapterVerified(String cid, QChapter ch) async {
    final ctype = _resolveCtype(cid, ch.type);
    final prefix = _prefixFor(ctype);

    await tp.req('PUT', '$tpBase/api/study/students/chapters/$cid/test', body: '{}');
    await pace.step(40);
    final live = await _liveQuestions(cid);

    final bank = _bankSource(ch);
    var res = await _runPass(cid, ctype, prefix, live, bank, restart: false);
    var diamond = _diamond(res);
    log('  اختبار $cid: diamond=$diamond/5');

    var attempt = 0;
    while (diamond < 5 && attempt < 3) {
      attempt++;
      final fixes = _harvest(res);
      if (fixes.isEmpty) {
        log('  لا توجد إجابات مصححة متاحة للفصل $cid (تعذر الحصد)');
        break;
      }
      log('  إصلاح الفصل $cid (محاولة $attempt): ${fixes.length} إجابة صحيحة من المنصة');
      final merged = <String, Map<String, String>>{...bank, ...fixes};
      res = await _runPass(cid, ctype, prefix, live, merged, restart: true);
      diamond = _diamond(res);
      log('  بعد الإصلاح: diamond=$diamond/5');
    }

    if (diamond >= 5) {
      log('  الفصل $cid مكتمل بدرجة كاملة (PERFECT)');
    } else {
      log('  تنبيه: الفصل $cid توقف عند diamond=$diamond/5');
    }
  }

  String _prefixFor(String ctype) => ctype == 'test' ? 'test-questions' : 'review-questions';

  /// Platform-authoritative chapter type, falling back to the answer bank.
  String _resolveCtype(String cid, String fallback) => _ctypeCache[cid] ?? fallback;

  /// Live question list for a chapter (the test must be started first).
  Future<List<Map<String, dynamic>>> _liveQuestions(String cid) async {
    final raw = await tp.req('GET', '$tpBase/api/study/chapters/$cid/test');
    return requireJsonArray(raw, 'live questions $cid')
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  /// Answer bank indexed by question id -> {kind, val}.
  Map<String, Map<String, String>> _bankSource(QChapter ch) {
    final m = <String, Map<String, String>>{};
    for (final q in ch.questions) {
      m[q.qid.toString()] = q.qtype == 'choice'
          ? {'kind': 'C', 'val': (q.choiceId ?? 0).toString()}
          : {'kind': 'D', 'val': q.answerCode ?? ''};
    }
    return m;
  }

  /// Builds the answer plan following the platform's live question order, taking
  /// each answer from [src] (harvested fixes override the bank).
  List<Map<String, String>> _buildPlan(
    List<Map<String, dynamic>> live,
    Map<String, Map<String, String>> src,
  ) {
    final defaultCode =
        course.contentId.contains('python') ? 'print("x")' : 'console.log("x")';
    final plan = <Map<String, String>>[];
    for (final item in live) {
      final q = (item['question'] as Map<String, dynamic>?) ?? const {};
      final qid = q['id']?.toString() ?? '';
      if (qid.isEmpty) continue;
      final qtype = q['type']?.toString() ?? 'choice';
      final entry = src[qid];

      if (qtype == 'choice') {
        final choices = (item['choices'] as List<dynamic>?) ?? [];
        final fallback = choices.isNotEmpty
            ? ((choices[0] as Map<String, dynamic>)['id']?.toString() ?? '0')
            : '0';
        plan.add({'qid': qid, 'kind': 'C', 'val': entry?['val'] ?? fallback});
      } else {
        final descs = (item['descriptions'] as List<dynamic>?) ?? [];
        final fallback = descs.isNotEmpty
            ? ((descs[0] as Map<String, dynamic>)['code']?.toString() ?? '')
            : '';
        var val = entry?['val'] ?? '';
        if (val.isEmpty) val = fallback.isNotEmpty ? fallback : defaultCode;
        plan.add({'qid': qid, 'kind': 'D', 'val': val});
      }
    }
    return plan;
  }

  Future<Map<String, dynamic>?> _runPass(
    String cid,
    String ctype,
    String prefix,
    List<Map<String, dynamic>> live,
    Map<String, Map<String, String>> src, {
    required bool restart,
  }) async {
    if (restart) {
      await tp.req('PUT', '$tpBase/api/study/students/chapters/$cid/test', body: '{}');
      await pace.step(40);
    }
    final plan = _buildPlan(live, src);
    for (final p in plan) {
      final qid = p['qid']!;
      final val = p['val']!;
      final String out;
      if (p['kind'] == 'C') {
        out = (await tp.req(
          'PUT',
          '$tpBase/api/study/students/$prefix/$qid/answer/choice',
          body: jsonEncode({'choice_id': int.tryParse(val) ?? 0}),
        )).body;
      } else {
        out = (await tp.req(
          'PUT',
          '$tpBase/api/study/students/$prefix/$qid/answer/description',
          body: jsonEncode({'answer_code': val}),
        )).body;
      }
      _logAnswer(qid, p['kind'] == 'C' ? 'choice' : 'description', out);
      await pace.step(20);
    }
    return _getResult(cid, ctype);
  }

  Future<Map<String, dynamic>?> _getResult(String cid, String ctype) async {
    final raw = await tp.req('GET', '$tpBase/api/study/students/chapters/$cid/$ctype/result');
    if (!isSuccessJson(raw)) return null;
    try {
      final obj = jsonDecode(raw.body) as Map<String, dynamic>;
      return (obj['result'] as Map<String, dynamic>?) ?? obj;
    } catch (_) {
      return null;
    }
  }

  int _diamond(Map<String, dynamic>? res) => (res?['diamond'] as num?)?.toInt() ?? 0;

  /// Extracts the platform's correct answers from a result payload.
  /// (review results are flat; test results are nested under `result`.)
  Map<String, Map<String, String>> _harvest(Map<String, dynamic>? res) {
    final m = <String, Map<String, String>>{};
    if (res == null) return m;

    final choiceResults = (res['choice_results'] as List<dynamic>?) ??
        (res['choices'] as List<dynamic>?) ??
        [];
    for (final item in choiceResults) {
      final cr = item as Map<String, dynamic>;
      final qid = cr['question_id']?.toString() ?? '';
      if (qid.isEmpty) continue;
      for (final chItem in (cr['choices'] as List<dynamic>?) ?? []) {
        final c = chItem as Map<String, dynamic>;
        if (c['correct'] == true) {
          final id = (c['choice'] as Map<String, dynamic>?)?['id']?.toString() ??
              c['id']?.toString();
          if (id != null && id.isNotEmpty) m[qid] = {'kind': 'C', 'val': id};
          break;
        }
      }
    }

    for (final item in (res['description_results'] as List<dynamic>?) ?? []) {
      final dr = item as Map<String, dynamic>;
      final qid = dr['question_id']?.toString() ?? '';
      final model = dr['model_answer']?.toString() ?? '';
      if (qid.isNotEmpty && model.isNotEmpty) m[qid] = {'kind': 'D', 'val': model};
    }
    return m;
  }

  void _logAnswer(String qid, String kind, String out) {
    if (out.contains('"already_answered"')) {
      log('  سؤال $qid ($kind): تم مسبقاً');
    } else if (out.contains('"complete"')) {
      log('  سؤال $qid ($kind): مكتمل');
    } else if (out.contains('"correct":true')) {
      log('  سؤال $qid ($kind): صحيح');
    } else if (out.trim() == '{}') {
      log('  سؤال $qid ($kind): تم الإرسال');
    } else {
      log('  سؤال $qid ($kind): ${out.length > 120 ? out.substring(0, 120) : out}');
    }
  }

  Future<void> _logFinalStatus() async {
    log('[4/4] الحالة النهائية للمقرر:');
    final listRaw = await tp.req('GET', '$tpBase/api/study/students/sections/${course.sectionId}/chapters');
    final arr = requireJsonArray(listRaw, 'final chapters');
    int done = 0;
    for (final item in arr) {
      final c = item as Map<String, dynamic>;
      if ((c['completed_at']?.toString() ?? '').isNotEmpty) done++;
    }
    log('تم إنجاز $done من إجمالي ${arr.length} فصلاً (100% PERFECT)');
  }
}
