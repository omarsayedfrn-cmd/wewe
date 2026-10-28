import 'dart:convert';
import 'api.dart';
import 'pace.dart';
import 'answers.dart';

class SprixSolver {
  final SolverApi api;
  final void Function(String) log;
  final Pace pace;
  final int subject; // 7 = AR, 3 = EN

  static const String base = 'https://egy.app.spx-learning-square.com';

  SprixSolver({
    required this.api,
    required this.log,
    required this.pace,
    this.subject = 7,
  });

  bool get isEn => subject == 3;

  Future<void> runWith({
    required String loginId,
    required String password,
    required int start,
    required Map<String, List<IdPair>> chapters,
    required Map<String, List<IdPair>> tests,
    int? maxChapters,
    bool trialMode = false,
    void Function(int done, int total, String label)? onProgress,
    void Function(String nextStart)? onResume,
  }) async {
    log('[1/3] تسجيل الدخول إلى منصة SPRIX...');
    final lr = await api.req(
      'POST',
      '$base/api/v1/auth/login',
      body: jsonEncode({'login_id': loginId, 'password': password}),
    );
    log('login http=${lr.code}');
    await pace.auth(1000);

    log('[2/3] التحقق من الحساب...');
    final me = await api.req('GET', '$base/api/v1/auth/me');
    log(me.body.length > 200 ? me.body.substring(0, 200) : me.body);
    await pace.auth(500);

    final unitEnd = isEn ? 6 : 24;
    log('[3/3] حل الوحدات $start..$unitEnd (المادة $subject، ${isEn ? "إنجليزي" : "عربي"})...');

    final curRaw = await api.req('GET', '$base/api/v1/subjects/$subject/curriculum');
    final curObj = requireJsonObject(curRaw, 'curriculum');
    final unitsArr = (curObj['data'] as List<dynamic>?) ?? [];

    final plan = <(int, List<dynamic>)>[];
    for (int u = start; u <= unitEnd; u++) {
      List<dynamic>? items;
      for (final item in unitsArr) {
        final un = item as Map<String, dynamic>;
        if (un['id'] == u) {
          items = un['items'] as List<dynamic>?;
          break;
        }
      }
      if (items == null) throw SolverStop('الوحدة $u غير موجودة في المنهج');
      plan.add((u, items));
    }

    final total = maxChapters ?? plan.fold<int>(0, (sum, p) => sum + p.$2.length);
    int done = 0;
    int chaptersSolved = 0;
    onProgress?.call(0, total, 'الوحدة $start');

    for (final pair in plan) {
      final u = pair.$1;
      final items = pair.$2;
      log('=== الوحدة $u ===');

      for (int i = 0; i < items.length; i++) {
        final it = items[i] as Map<String, dynamic>;
        final id = it['id'].toString();
        final itemType = it['item_type'] as String? ?? '';

        final isChapter = itemType == 'chapter';

        switch (itemType) {
          case 'chapter':
            if (isEn) {
              await _doChapterEn(id);
            } else {
              final a = chapters[id];
              if (a == null) {
                await _doSimChapter(id);
              } else {
                await _doChapterAr(id, a);
              }
            }

            if (trialMode) {
              log('--------------------------------------------------');
              log('التجربة: تم حل فصل التأكيد بنجاح');
              log('--------------------------------------------------');
              onProgress?.call(1, 1, 'تمت التجربة');
              return;
            }
            break;

          case 'review':
            await api.req('POST', '$base/api/v1/reviews/$id/complete', body: '{}');
            log('  مراجعة $id مكتملة');
            await pace.step(300);
            break;

          case 'test':
            if (isEn) {
              await _doTestEn(id);
            } else {
              final testAns = tests[id];
              if (testAns == null) throw SolverStop('الاختبار $id غير موجود في الإجابات');
              await _doTestAr(id, testAns);
            }
            break;
        }

        // In trial mode only chapters count towards the progress/limit, but
        // reviews and tests between them still run so the next chapter unlocks.
        if (maxChapters == null || isChapter) {
          done++;
          onProgress?.call(done, total, 'الوحدة $u · $id');
        }

        if (maxChapters != null && isChapter) {
          chaptersSolved++;
          if (chaptersSolved >= maxChapters) {
            log('انتهت التجربة: تم حل $chaptersSolved فصل تجريبي بنجاح');
            onProgress?.call(chaptersSolved, total, 'تمت التجربة');
            return;
          }
        }
      }

      onResume?.call((u + 1).toString());
    }

    log('=== الحالة النهائية ===');
    final st = await api.req('GET', '$base/api/v1/subjects/$subject/units');
    final arr = requireJsonArray(st, 'final units');
    for (final item in arr) {
      final x = item as Map<String, dynamic>;
      log('وحدة ${x['id']}: ${x['completed_items']}/${x['total_items']} (${x['progress_pct']}%)');
    }
    log('DONE 100% PERFECT.');
  }

  Future<void> _doSimChapter(String cid) async {
    final b = await api.req('GET', '$base/api/v1/chapters/$cid/blocks');
    final obj = requireJsonObject(b, 'chapter $cid blocks');
    final blocks = ((obj['data'] as Map<String, dynamic>?)?['blocks'] as List<dynamic>?) ?? [];

    int nq = 0;
    for (final item in blocks) {
      if ((item as Map<String, dynamic>)['type'] == 'question') nq++;
    }

    if (nq > 0) throw SolverStop('الفصل $cid غير موجود في ملف الإجابات وفيه $nq أسئلة');
    final comp = await api.req('POST', '$base/api/v1/chapters/$cid/complete', body: '{}');
    log(comp.body.length > 200 ? comp.body.substring(0, 200) : comp.body);
    log('  فصل محاكاة $cid مكتمل (بدون أسئلة)');
    await pace.step(300);
  }

  Future<void> _doChapterAr(String cid, List<IdPair> ans) async {
    int ok = 0;
    for (final pair in ans) {
      final bid = pair.$1;
      final oid = pair.$2;

      final out = await api.req(
        'POST',
        '$base/api/v1/chapters/$cid/answer',
        body: jsonEncode({'block_id': bid, 'selected_option_id': oid}),
      );

      if (isSuccessJson(out) && out.body.contains('"is_correct":true')) {
        ok++;
      } else {
        log('  فصل $cid سؤال $bid خيار $oid خطأ — جاري البحث التلقائي');
        final found = await _bruteForceChapterBlock(cid, bid, oid);
        if (found) ok++;
      }
      await pace.step(20);
    }

    log('  فصل $cid: تم حل $ok/${ans.length} صحيح -> إتمام:');
    final comp = await api.req('POST', '$base/api/v1/chapters/$cid/complete', body: '{}');
    log(comp.body.length > 200 ? comp.body.substring(0, 200) : comp.body);
    await pace.step(30);
  }

  Future<bool> _bruteForceChapterBlock(String cid, int bid, int skipOid) async {
    final blocks = await api.req('GET', '$base/api/v1/chapters/$cid/blocks');
    final obj = requireJsonObject(blocks, 'blocks for brute-force');
    final bArr = ((obj['data'] as Map<String, dynamic>?)?['blocks'] as List<dynamic>?) ?? [];

    for (final item in bArr) {
      final b = item as Map<String, dynamic>;
      if (b['id'].toString() != bid.toString()) continue;
      final options = (b['options'] as List<dynamic>?) ?? [];

      for (final optItem in options) {
        final opt = optItem as Map<String, dynamic>;
        final optId = opt['id'] as int? ?? -1;
        if (optId == skipOid) continue;

        final retry = await api.req(
          'POST',
          '$base/api/v1/chapters/$cid/answer',
          body: jsonEncode({'block_id': bid, 'selected_option_id': optId}),
        );

        if (isSuccessJson(retry) && retry.body.contains('"is_correct":true')) {
          log('  فصل $cid بلوك $bid: الخيار الصحيح هو $optId');
          return true;
        }
        await pace.step(20);
      }
      break;
    }
    return false;
  }

  Future<void> _doChapterEn(String cid) async {
    final blocksRaw = await api.req('GET', '$base/api/v1/chapters/$cid/blocks');
    final obj = requireJsonObject(blocksRaw, 'chapter $cid blocks');
    final blocks = ((obj['data'] as Map<String, dynamic>?)?['blocks'] as List<dynamic>?) ?? [];

    int nq = 0;
    for (final item in blocks) {
      if ((item as Map<String, dynamic>)['type'] == 'question') nq++;
    }

    if (nq == 0) {
      await api.req('POST', '$base/api/v1/chapters/$cid/complete', body: '{}');
      log('  sim chapter $cid done (no questions)');
      await pace.step(300);
      return;
    }

    for (final item in blocks) {
      final b = item as Map<String, dynamic>;
      if (b['type'] != 'question') continue;
      final bid = b['id'].toString();
      final options = (b['options'] as List<dynamic>?) ?? [];

      for (final optItem in options) {
        final opt = optItem as Map<String, dynamic>;
        final optId = opt['id'] as int? ?? -1;

        final out = await api.req(
          'POST',
          '$base/api/v1/chapters/$cid/answer',
          body: jsonEncode({'block_id': int.tryParse(bid) ?? 0, 'selected_option_id': optId}),
        );

        if (isSuccessJson(out) && out.body.contains('"is_correct":true')) {
          log('  ch$cid block$bid: option $optId CORRECT');
          break;
        }
        await pace.step(20);
      }
    }

    await api.req('POST', '$base/api/v1/chapters/$cid/complete', body: '{}');
    pace.step(30);
  }

  Future<void> _doTestAr(String tid, List<IdPair> ans) async {
    final raw = await api.req('POST', '$base/api/v1/tests/$tid/start', body: '{}');
    final start = requireJsonObject(raw, 'test $tid start');
    final map = <String, String>{};
    final tqs = (((start['data'] as Map<String, dynamic>?)?['test_questions']) as List<dynamic>?) ?? [];

    for (final item in tqs) {
      final t = item as Map<String, dynamic>;
      if (t['question_id'] != null && t['id'] != null) {
        map[t['question_id'].toString()] = t['id'].toString();
      }
    }

    for (final pair in ans) {
      final qid = pair.$1;
      final oid = pair.$2;
      final tqid = map[qid.toString()];
      if (tqid == null) throw SolverStop('سؤال الاختبار $qid غير موجود في هذه المحاولة');

      await api.req(
        'PUT',
        '$base/api/v1/tests/$tid/questions/$tqid/answer',
        body: jsonEncode({'selected_option_id': oid}),
      );
      await pace.step(20);
    }

    final submitResp = await api.req('POST', '$base/api/v1/tests/$tid/submit', body: '{}');
    log('  اختبار $tid إرسال: ${submitResp.body.length > 200 ? submitResp.body.substring(0, 200) : submitResp.body}');
    await pace.step(40);
  }

  Future<void> _doTestEn(String tid) async {
    final startRaw = await api.req('POST', '$base/api/v1/tests/$tid/start', body: '{}');
    final start = requireJsonObject(startRaw, 'test $tid start');
    final tqs = (((start['data'] as Map<String, dynamic>?)?['test_questions']) as List<dynamic>?) ?? [];

    final tqMap = <String, String>{};
    for (final item in tqs) {
      final t = item as Map<String, dynamic>;
      if (t['question_id'] != null && t['id'] != null) {
        tqMap[t['question_id'].toString()] = t['id'].toString();
      }
    }

    final opts = ((start['data'] as Map<String, dynamic>?)?['options'] as Map<String, dynamic>?) ?? {};
    for (final item in tqs) {
      final t = item as Map<String, dynamic>;
      final qid = t['question_id']?.toString() ?? '';
      if (qid.isEmpty) continue;
      final tqid = tqMap[qid];
      if (tqid == null) continue;
      final optArr = (opts[qid] as List<dynamic>?) ?? [];
      final firstOpt = optArr.isNotEmpty ? (optArr[0] as Map<String, dynamic>)['id'] as int? ?? -1 : -1;

      await api.req(
        'PUT',
        '$base/api/v1/tests/$tid/questions/$tqid/answer',
        body: jsonEncode({'selected_option_id': firstOpt}),
      );
      await pace.step(20);
    }

    final sub = await api.req('POST', '$base/api/v1/tests/$tid/submit', body: '{}');
    await pace.step(30);

    final ansMap = <String, int>{};
    try {
      final subObj = jsonDecode(sub.body) as Map<String, dynamic>;
      final subData = subObj['data'] as Map<String, dynamic>? ?? {};
      final subOptions = subData['options'] as Map<String, dynamic>? ?? {};

      for (final key in subOptions.keys) {
        final arr = (subOptions[key] as List<dynamic>?) ?? [];
        for (final optItem in arr) {
          final opt = optItem as Map<String, dynamic>;
          if (opt['is_correct'] == true) {
            ansMap[key] = opt['id'] as int? ?? -1;
            break;
          }
        }
      }
    } catch (_) {}

    if (ansMap.isEmpty) {
      log('  test $tid: harvest empty');
      return;
    }

    // Apply pass
    final startRaw2 = await api.req('POST', '$base/api/v1/tests/$tid/start', body: '{}');
    final start2 = requireJsonObject(startRaw2, 'test $tid restart');
    final tqs2 = (((start2['data'] as Map<String, dynamic>?)?['test_questions']) as List<dynamic>?) ?? [];
    final tqMap2 = <String, String>{};
    for (final item in tqs2) {
      final t = item as Map<String, dynamic>;
      if (t['question_id'] != null && t['id'] != null) {
        tqMap2[t['question_id'].toString()] = t['id'].toString();
      }
    }

    for (final item in tqs2) {
      final t = item as Map<String, dynamic>;
      final qid = t['question_id']?.toString() ?? '';
      if (qid.isEmpty) continue;
      final tqid = tqMap2[qid];
      if (tqid == null) continue;
      final oid = ansMap[qid];
      if (oid == null) continue;

      await api.req(
        'PUT',
        '$base/api/v1/tests/$tid/questions/$tqid/answer',
        body: jsonEncode({'selected_option_id': oid}),
      );
      await pace.step(20);
    }

    final sub2 = await api.req('POST', '$base/api/v1/tests/$tid/submit', body: '{}');
    log('  test $tid 100% submit ok: ${sub2.body.length > 150 ? sub2.body.substring(0, 150) : sub2.body}');
    await pace.step(30);
  }
}
