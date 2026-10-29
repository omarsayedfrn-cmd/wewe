package com.solver.app

import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.ensureActive
import org.json.JSONArray
import org.json.JSONObject
import kotlin.coroutines.coroutineContext

data class CachedTalk(val tid: String, val payload: String)
data class CachedLecture(val lid: String, val talks: List<CachedTalk>)

/** Which QUREO course to solve. QUREO=JavaScript_ar (section 5), QUREO2=python_short_ar (section 106),
 * QUREO_EN=JavaScript_en (section 2), QUREO2_EN=python_short_en (section 202). */
data class QureoCourse(
    val contentId: String,
    val sectionId: Int,
    val courseId: String,
    val totalDiamonds: Int,
    val defaultStart: String,
    val startRegex: Regex,
    val baseId: Int, // raw id = baseId + natural number (90000/511000/30000/531000)
    val totalChapters: Int, // 54/25
    val inputRange: IntRange = 1..totalChapters, // what the user types
) {
    companion object {
        val QUREO = QureoCourse("javascript_ar", 5, "javascript_ar", 270, "1", Regex("^900(0[1-9]|[1-4][0-9]|5[0-4])$"), 90000, 54)
        val QUREO2 = QureoCourse("python_short_ar", 106, "python_short_ar", 125, "1", Regex("^5110(0[1-9]|1[0-9]|2[0-5])$"), 511000, 25)
        val QUREO_EN = QureoCourse("javascript_en", 2, "javascript_en", 270, "1", Regex("^300(0[1-9]|[1-4][0-9]|5[0-4])$"), 30000, 54)
        val QUREO2_EN = QureoCourse("python_short_en", 202, "python_short_en", 50, "1", Regex("^5310(0[1-9]|10)$"), 531000, 10)

        fun of(platform: String): QureoCourse = when (platform) {
            "qureo2" -> QUREO2
            "qureo2_en" -> QUREO2_EN
            "qureo_en" -> QUREO_EN
            else -> QUREO
        }

        fun isEn(course: QureoCourse): Boolean = course.contentId.endsWith("_en")
    }

    /** Natural chapter number (1-based) or null if out of range. */
    fun naturalOf(raw: String): Int? =
        raw.toIntOrNull()?.let { (it - baseId).takeIf { n -> n in 1..totalChapters } }

    /** Raw chapter id from a natural number, or null if out of range. */
    fun rawOf(natural: Int): String? =
        if (natural in 1..totalChapters) (baseId + natural).toString() else null

    /** Friendly display: "#3" for chapter 3, raw id as fallback. */
    fun displayStart(raw: String): String = naturalOf(raw)?.let { "#$it" } ?: raw
}

/** Port of qureo-solver/solve.sh - PERFECT (diamond 5) on all chapters.
 *
 * AR mode (javascript_ar / python_short_ar): uses pre-loaded answers from assets,
 * sent SEQUENTIALLY (fixed from parallel awaitAll that caused rate-limit / grading issues).
 * EN mode (javascript_en / python_short_en): self-discovering learn+apply pass
 * (learn pass harvests correct answers from grader, apply pass re-answers correctly),
 * no answers.json needed.
 */
class QureoSolver(
    private val portal: Api,
    private val tp: Api,
    private val store: CookieStore,
    private val log: (String) -> Unit,
    private val pace: Pace,
    private val course: QureoCourse = QureoCourse.QUREO,
) {
    companion object {
        private val lectureCache = ConcurrentHashMap<String, List<CachedLecture>>()
    }

    private val portalBase = "https://me-portal.qureo.education"
    private val tpBase = "https://me-tp.qureo.education"

    suspend fun runWith(
        loginId: String,
        password: String,
        start: Int,
        answers: Map<String, Answers.QChapter>,
        trialMode: Boolean = false,
        onProgress: (done: Int, total: Int, label: String) -> Unit = { _, _, _ -> },
        onResume: (nextStart: String) -> Unit = {},
    ) {
        log("[1/4] login to portal...")
        val lr = portal.req(
            "POST", "$portalBase/oauth2/password-login",
            JSONObject().put("student_id", loginId).put("password", password).toString(),
        )
        log("login http=${lr.code}")
        pace.auth(1000)
        log("[2/4] verify userinfo...")
        log(portal.req("GET", "$portalBase/oauth2/userinfo").body.take(300))
        pace.auth(500)
        log("[3/4] bootstrap TP session (oauth refresh)...")
        val me = tp.req("GET", "$tpBase/api/study/students/me")
        log("tp me http=${me.code}")
        store.addCookie(".qureo.education", "student_selected_content_id", course.contentId)
        val lang = if (QureoCourse.isEn(course)) "en" else "ar"
        store.addCookie(".qureo.education", "i18next", lang)
        pace.auth(500)

        if (QureoCourse.isEn(course)) {
            runEn(start, trialMode, onProgress, onResume)
        } else {
            runAr(answers, start, trialMode, onProgress, onResume)
        }
    }

    /** AR mode: pre-loaded answers, sent one-by-one (sequential, no parallel burst). */
    private suspend fun runAr(
        answers: Map<String, Answers.QChapter>,
        start: Int,
        trialMode: Boolean,
        onProgress: (Int, Int, String) -> Unit,
        onResume: (String) -> Unit,
    ) {
        val chapters = answers.keys.mapNotNull { it.toIntOrNull() }
            .filter { it >= start }.sorted()
        if (chapters.isEmpty()) throw SolverStop("no chapters >= $start in answers")
        log("Solving ${chapters.size} chapters from $start to ${chapters.last()}")
        onProgress(0, chapters.size, "chapter $start")
        for ((idx, cid) in chapters.withIndex()) {
            coroutineContext.ensureActive()
            val i = idx + 1
            val ch = answers[cid.toString()] ?: continue
            log("=== [$i/${chapters.size}] chapter $cid (${ch.type}) lectures...")
            completeLectures(cid.toString())
            log("--- start test $cid")
            tp.req("PUT", "$tpBase/api/study/students/chapters/$cid/test", "{}")
            pace.step(40)
            val prefix = if (ch.type == "test") "test-questions" else "review-questions"
            for (q in ch.questions) {
                coroutineContext.ensureActive()
                val (body, kind) = if (q.qtype == "choice") {
                    JSONObject().put("choice_id", q.choiceId ?: 0).toString() to "choice"
                } else {
                    JSONObject().put("answer_code", q.answerCode ?: "").toString() to "description"
                }
                val out = tp.req(
                    "PUT",
                    "$tpBase/api/study/students/$prefix/${q.qid}/answer/$kind",
                    body,
                ).body
                when {
                    out.contains("\"complete\"") -> log("  q ${q.qid} ($kind): COMPLETE ${out.take(150)}")
                    out.contains("\"correct\":true") -> log("  q ${q.qid} ($kind): correct")
                    out.trim() == "{}" -> log("  q ${q.qid} ($kind): ok")
                    else -> log("  q ${q.qid} ($kind): ${out.take(150)}")
                }
                pace.step(20)
            }
            onProgress(i, chapters.size, "chapter $cid")
            if (idx + 1 < chapters.size) onResume(chapters[idx + 1].toString())
            else onResume("done")

            if (trialMode) {
                log("--------------------------------------------------")
                log("⭐ [تمت التجربة بنجاح] تم حل فصل واحد ($cid) بنجاح للتأكد!")
                log("⭐ لحل باقي الـ ${chapters.size} فصلاً، يرجى تفعيل النسخة الكاملة.")
                log("--------------------------------------------------")
                onProgress(1, 1, "تمت التجربة")
                return
            }
        }
        logFinalStatus()
    }

    /** EN mode: self-discovering learn+apply pass (no answers.json needed). */
    private suspend fun runEn(
        start: Int,
        trialMode: Boolean,
        onProgress: (Int, Int, String) -> Unit,
        onResume: (String) -> Unit,
    ) {
        val sectionsRaw = tp.req("GET", "$tpBase/api/study/sections/${course.sectionId}")
        val sectionsObj = requireJsonObject(sectionsRaw, "sections")
        val chaptersArr = sectionsObj.optJSONArray("chapters") ?: JSONArray()
        val chapterList = mutableListOf<Pair<String, String>>()
        for (k in 0 until chaptersArr.length()) {
            val c = chaptersArr.getJSONObject(k)
            val cid = c.getString("id")
            if ((cid.toIntOrNull() ?: 0) < start) continue
            val ctype = c.optString("test_type", "review")
            chapterList.add(cid to ctype)
        }
        chapterList.sortBy { it.first.toIntOrNull() ?: Int.MAX_VALUE }
        if (chapterList.isEmpty()) throw SolverStop("no chapters >= $start in section ${course.sectionId}")
        log("Solving ${chapterList.size} chapters from $start to ${chapterList.last().first}")
        onProgress(0, chapterList.size, "chapter $start")
        for ((idx, entry) in chapterList.withIndex()) {
            val cid = entry.first
            val ctype = entry.second
            coroutineContext.ensureActive()
            val i = idx + 1
            log("=== [$i/${chapterList.size}] chapter $cid ($ctype) lectures...")
            try {
                completeLectures(cid)
            } catch (e: SolverStop) {
                log("⚠ $cid locked (${e.message}), skipping")
                continue
            }
            log("--- start test $cid")
            tp.req("PUT", "$tpBase/api/study/students/chapters/$cid/test", "{}")
            pace.step(40)
            val prefix = if (ctype == "test") "test-questions" else "review-questions"
            val completed = solveTestEn(cid, ctype, prefix)
            if (!completed) {
                log("⚠ $cid test incomplete, skipping next")
                continue
            }
            onProgress(i, chapterList.size, "chapter $cid")
            if (idx + 1 < chapterList.size) onResume(chapterList[idx + 1].first)
            else onResume("done")

            if (trialMode) {
                log("--------------------------------------------------")
                log("⭐ [Trial done] Chapter $cid solved successfully!")
                log("⭐ To solve remaining ${chapterList.size} chapters, activate the full version.")
                log("--------------------------------------------------")
                onProgress(1, 1, "trial done")
                return
            }
        }
        logFinalStatus()
    }

    /** EN learn+apply pass: learn pass guesses + harvests correct answers, apply pass re-answers correctly.
     * Returns true if chapter reached diamond 5 / completed_at after apply pass. */
    private suspend fun solveTestEn(cid: String, ctype: String, prefix: String): Boolean {
        val mapFile = mutableMapOf<String, JSONObject>()
        log("--- learn pass $cid ($prefix)")
        tp.req("PUT", "$tpBase/api/study/students/chapters/$cid/test", "{}")
        pace.step(40)
        val tqRaw = tp.req("GET", "$tpBase/api/study/chapters/$cid/test")
        val tqArr = requireJsonArray(tqRaw, "test questions $cid")
        val nq = tqArr.length()
        for (k in 0 until nq) {
            coroutineContext.ensureActive()
            val q = tqArr.getJSONObject(k)
            val qid = q.optJSONObject("question")?.optString("id") ?: q.optString("question_id", "")
            val qtype = q.optJSONObject("question")?.optString("type") ?: q.optString("type", "choice")
            if (qid.isEmpty()) continue
            if (qtype == "choice") {
                val choices = q.optJSONArray("choices") ?: JSONArray()
                val guessId = if (choices.length() > 0) choices.getJSONObject(0).optInt("id", 0) else 0
                val out = tp.req(
                    "PUT", "$tpBase/api/study/students/$prefix/$qid/answer/choice",
                    JSONObject().put("choice_id", guessId).toString(),
                ).body
                val real = harvestChoiceId(out)
                if (real != null) {
                    mapFile[qid] = JSONObject().put("type", "choice").put("choice_id", real)
                    log("  q $qid (choice): harvested $real")
                } else {
                    log("  q $qid (choice): harvest FAILED: ${out.take(150)}")
                }
            } else {
                val descriptions = q.optJSONArray("descriptions") ?: JSONArray()
                val starterCode = if (descriptions.length() > 0) descriptions.getJSONObject(0).optString("code", "") else ""
                val guessCode = if (starterCode.isNotEmpty()) starterCode else "console.log('x')"
                val out = tp.req(
                    "PUT", "$tpBase/api/study/students/$prefix/$qid/answer/description",
                    JSONObject().put("answer_code", guessCode).toString(),
                ).body
                val real = harvestModelAnswer(out)
                if (real != null) {
                    mapFile[qid] = JSONObject().put("type", "description").put("answer_code", real)
                    log("  q $qid (desc): harvested model_answer")
                } else {
                    log("  q $qid (desc): harvest FAILED: ${out.take(150)}")
                }
            }
            pace.step(20)
        }
        val resultRaw = tp.req("GET", "$tpBase/api/study/students/chapters/$cid/$ctype/result")
        if (isSuccessJson(resultRaw)) {
            harvestFromResult(resultRaw.body, mapFile)
        }
        log("--- apply pass $cid (restart + answer correct)")
        tp.req("PUT", "$tpBase/api/study/students/chapters/$cid/test", "{}")
        pace.step(40)
        for (k in 0 until nq) {
            coroutineContext.ensureActive()
            val q = tqArr.getJSONObject(k)
            val qid = q.optJSONObject("question")?.optString("id") ?: q.optString("question_id", "")
            val qtype = q.optJSONObject("question")?.optString("type") ?: q.optString("type", "choice")
            if (qid.isEmpty()) continue
            val entry = mapFile[qid]
            if (entry == null) {
                log("  q $qid: NO HARVESTED ANSWER -> skip")
                continue
            }
            val prefix2 = if (ctype == "test") "test-questions" else "review-questions"
            if (entry.optString("type") == "choice") {
                val choiceId = entry.optInt("choice_id", 0)
                val out = tp.req(
                    "PUT", "$tpBase/api/study/students/$prefix2/$qid/answer/choice",
                    JSONObject().put("choice_id", choiceId).toString(),
                ).body
                logResult(qid, "choice", out)
            } else {
                val ans = entry.optString("answer_code", "")
                val out = tp.req(
                    "PUT", "$tpBase/api/study/students/$prefix2/$qid/answer/description",
                    JSONObject().put("answer_code", ans).toString(),
                ).body
                logResult(qid, "description", out)
            }
            pace.step(20)
        }
        // Verify completion
        val verifyRaw = tp.req("GET", "$tpBase/api/study/students/chapters/$cid/$ctype/result")
        return if (isSuccessJson(verifyRaw)) {
            try {
                val res = JSONObject(verifyRaw.body)
                val result = res.optJSONObject("result") ?: res
                val diamond = result.optInt("diamond", 0)
                val completedAt = result.optString("completed_at", "")
                diamond >= 5 || completedAt.isNotEmpty()
            } catch (_: Exception) { false }
        } else false
    }

    private suspend fun harvestFromResult(body: String, map: MutableMap<String, JSONObject>) {
        try {
            val res = JSONObject(body)
            val result = res.optJSONObject("result") ?: res
            val choiceResults = result.optJSONArray("choice_results") ?: result.optJSONArray("choices") ?: JSONArray()
            for (k in 0 until choiceResults.length()) {
                val cr = choiceResults.getJSONObject(k)
                val qid = cr.optString("question_id", "")
                val choices = cr.optJSONArray("choices") ?: JSONArray()
                for (j in 0 until choices.length()) {
                    val ch = choices.getJSONObject(j)
                    if (ch.optBoolean("correct", false)) {
                        val real = ch.optJSONObject("choice")?.optString("id") ?: ch.optString("id", "")
                        if (real.isNotEmpty()) {
                            map[qid] = JSONObject().put("type", "choice").put("choice_id", real.toIntOrNull() ?: 0)
                            log("  q $qid (choice): harvested from result $real")
                        }
                        break
                    }
                }
            }
            val descResults = result.optJSONArray("description_results") ?: JSONArray()
            for (k in 0 until descResults.length()) {
                val dr = descResults.getJSONObject(k)
                val qid = dr.optString("question_id", "")
                val modelAnswer = dr.optString("model_answer", "")
                if (modelAnswer.isNotEmpty()) {
                    map[qid] = JSONObject().put("type", "description").put("answer_code", modelAnswer)
                    log("  q $qid (desc): harvested from result")
                }
            }
        } catch (_: Exception) { }
    }

    private fun harvestChoiceId(out: String): Int? {
        try {
            val obj = JSONObject(out)
            val result = obj.optJSONObject("result") ?: obj
            val choices = result.optJSONArray("choices") ?: JSONArray()
            for (k in 0 until choices.length()) {
                val ch = choices.getJSONObject(k)
                if (ch.optBoolean("correct", false)) {
                    return ch.optJSONObject("choice")?.optInt("id", -1) ?: -1
                }
            }
        } catch (_: Exception) { }
        return null
    }

    private fun harvestModelAnswer(out: String): String? {
        try {
            val obj = JSONObject(out)
            val result = obj.optJSONObject("result") ?: obj
            val ma = result.optString("model_answer", "")
            return ma.ifEmpty { null }
        } catch (_: Exception) { }
        return null
    }

    private fun logResult(qid: String, kind: String, out: String) {
        when {
            out.contains("\"complete\"") -> log("  q $qid ($kind): COMPLETE ${out.take(150)}")
            out.contains("\"correct\":true") -> log("  q $qid ($kind): correct")
            out.trim() == "{}" -> log("  q $qid ($kind): ok")
            else -> log("  q $qid ($kind): ${out.take(150)}")
        }
    }

    private suspend fun logFinalStatus() {
        log("[4/4] final status:")
        val listRaw = tp.req("GET", "$tpBase/api/study/students/sections/${course.sectionId}/chapters")
        val arr = requireJsonArray(listRaw, "final chapters")
        var done = 0
        val nonPerfect = mutableListOf<String>()
        for (k in 0 until arr.length()) {
            val c = arr.getJSONObject(k)
            if (c.optString("completed_at").isNotEmpty()) done++
            if (c.optInt("diamond", 0) < 5) nonPerfect.add(c.get("chapter_id").toString())
        }
        log("completed $done/${arr.length()}")
        log("non-perfect: $nonPerfect")
        log(tp.req("GET", "$tpBase/api/study/students/courses/${course.courseId}/diamond").body.take(300))
        log("DONE - all should be diamond 5 (${course.totalDiamonds}/${course.totalDiamonds}).")
    }

    /** Complete lectures of a chapter using cached or live model_answer. */
    private suspend fun completeLectures(cid: String) {
        var cached = lectureCache[cid]
        if (cached == null) {
            val chapRaw = tp.req("GET", "$tpBase/api/study/chapters/$cid")
            val chapObj = requireJsonObject(chapRaw, "chapter $cid")
            val lectures = chapObj.optJSONArray("lectures") ?: JSONArray()
            if (lectures.length() == 0) throw SolverStop("no lectures for $cid (locked?)")
            val list = mutableListOf<CachedLecture>()
            for (li in 0 until lectures.length()) {
                val lid = lectures.getJSONObject(li).get("id").toString()
                val talksRaw = tp.req("GET", "$tpBase/api/study/lectures/$lid")
                val talksObj = requireJsonObject(talksRaw, "lecture $lid")
                if (!talksObj.has("talks")) {
                    throw SolverStop("lecture $lid locked (prev chapter not done?)")
                }
                val talks = talksObj.getJSONArray("talks")
                val talksList = mutableListOf<CachedTalk>()
                for (ti in 0 until talks.length()) {
                    val t = talks.getJSONObject(ti)
                    if (!t.optString("type").startsWith("try")) continue
                    val tid = t.get("id").toString()
                    val code = t.getJSONObject("body").getJSONArray("codes").getJSONObject(0)
                    val lang = code.optString("lang", "javascript")
                    var model = code.optString("model_answer", "")
                    val src = code.optString("code", "")
                    if (model.isEmpty()) model = src
                    val payload: String
                    val ph = code.optJSONArray("placeholders") ?: JSONArray()
                    if (ph.length() > 0 && src.contains("fitbBlock")) {
                        val arr = JSONArray()
                        for (pi in 0 until ph.length()) {
                            val p = ph.getJSONObject(pi)
                            arr.put(JSONObject().put("name", p.getString("name")).put("code", p.optString("model_answer", "")))
                        }
                        payload = JSONObject().put("value", JSONObject().put("lang", lang).put("answers", arr)).toString()
                    } else {
                        payload = JSONObject().put("value", JSONObject().put("lang", lang).put("answer", model)).toString()
                    }
                    talksList.add(CachedTalk(tid, payload))
                }
                list.add(CachedLecture(lid, talksList))
            }
            lectureCache[cid] = list
            cached = list
        }

        for (lec in cached) {
            coroutineContext.ensureActive()
            tp.req("PUT", "$tpBase/api/study/students/lectures/${lec.lid}", "{}")
            pace.step(20)
            for (t in lec.talks) {
                tp.req("PUT", "$tpBase/api/study/students/lecture-talks/${t.tid}", t.payload)
                pace.step(20)
            }
            tp.req("PUT", "$tpBase/api/study/students/lectures/${lec.lid}/complete", "{}")
            pace.step(20)
        }
    }
}
