package com.solver.app

import kotlinx.coroutines.ensureActive
import org.json.JSONObject
import kotlin.coroutines.coroutineContext

/** Which QUREO course to solve. QUREO=JavaScript_ar (section 5), QUREO2=python_short_ar (section 106). */
data class QureoCourse(
    val contentId: String,
    val sectionId: Int,
    val courseId: String,
    val totalDiamonds: Int,
    val defaultStart: String,
    val startRegex: Regex,
    val baseId: Int, // raw id = baseId + natural number (90000/511000)
    val totalChapters: Int, // 54/25
    val inputRange: IntRange = 1..totalChapters, // what the user types
) {
    companion object {
        val QUREO = QureoCourse("javascript_ar", 5, "javascript_ar", 270, "1", Regex("^900[0-5][0-9]$"), 90000, 54)
        val QUREO2 = QureoCourse("python_short_ar", 106, "python_short_ar", 125, "1", Regex("^5110(0[1-9]|1[0-9]|2[0-5])$"), 511000, 25)

        fun of(platform: String): QureoCourse = if (platform == "qureo2") QUREO2 else QUREO
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

/** Port of qureo-solver/solve.sh - PERFECT (diamond 5) on all 54 chapters. */
class QureoSolver(
    private val portal: Api,
    private val tp: Api,
    private val store: CookieStore,
    private val log: (String) -> Unit,
    private val pace: Pace,
    private val course: QureoCourse = QureoCourse.QUREO,
) {
    private val portalBase = "https://me-portal.qureo.education"
    private val tpBase = "https://me-tp.qureo.education"

    suspend fun runWith(
        loginId: String,
        password: String,
        start: Int,
        answers: Map<String, Answers.QChapter>,
        onProgress: (done: Int, total: Int, label: String) -> Unit = { _, _, _ -> },
        onResume: (nextStart: String) -> Unit = {},
    ) {
        log("[1/4] login to portal...")
        val lr = portal.req(
            "POST", "$portalBase/oauth2/password-login",
            JSONObject().put("student_id", loginId).put("password", password).toString(),
        )
        log("login http=${lr.code}")
        // Login/bootstrap delays are never scaled by Boost (auth endpoints are
        // the most rate-limit sensitive; the batch evidence only covers loops).
        pace.auth(1000)
        log("[2/4] verify userinfo...")
        log(portal.req("GET", "$portalBase/oauth2/userinfo").body.take(300))
        pace.auth(500)
        log("[3/4] bootstrap TP session (oauth refresh)...")
        val me = tp.req("GET", "$tpBase/api/study/students/me")
        log("tp me http=${me.code}")
        // TP requires selected-content cookie (browser always sends it).
        // Without it /api/study/chapters/* returns non-JSON.
        store.addCookie(".qureo.education", "student_selected_content_id", course.contentId)
        store.addCookie(".qureo.education", "i18next", "ar")
        pace.auth(500)

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
            pace.step(400)
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
                // test-questions returns {} until the last one returns {"complete":{...}}
                when {
                    out.contains("\"complete\"") -> log("  q ${q.qid} ($kind): COMPLETE ${out.take(150)}")
                    out.contains("\"correct\":true") -> log("  q ${q.qid} ($kind): correct")
                    out.trim() == "{}" -> log("  q ${q.qid} ($kind): ok")
                    else -> log("  q ${q.qid} ($kind): ${out.take(150)}")
                }
                pace.step(500)
            }
            onProgress(i, chapters.size, "chapter $cid")
            // Next retry can skip this fully-done chapter.
            if (idx + 1 < chapters.size) onResume(chapters[idx + 1].toString())
            else onResume("done")
        }
        log("[4/4] final status:")
        val list = tp.req("GET", "$tpBase/api/study/students/sections/${course.sectionId}/chapters").body
        val arr = if (isJson(list)) org.json.JSONArray(list) else org.json.JSONArray()
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

    /** Complete lectures of a chapter using live model_answer (no hardcode needed). */
    private suspend fun completeLectures(cid: String) {
        val chapRaw = tp.req("GET", "$tpBase/api/study/chapters/$cid")
        if (!isJson(chapRaw.body)) throw SolverStop("chapter $cid non-JSON: ${chapRaw.body.take(200)}")
        val lectures = JSONObject(chapRaw.body).optJSONArray("lectures") ?: org.json.JSONArray()
        if (lectures.length() == 0) throw SolverStop("no lectures for $cid (locked?)")
        for (li in 0 until lectures.length()) {
            coroutineContext.ensureActive()
            val lid = lectures.getJSONObject(li).get("id").toString()
            tp.req("PUT", "$tpBase/api/study/students/lectures/$lid", "{}")
            pace.step(300)
            val talksRaw = tp.req("GET", "$tpBase/api/study/lectures/$lid")
            if (!isJson(talksRaw.body)) throw SolverStop("lecture $lid non-JSON")
            val talksObj = JSONObject(talksRaw.body)
            if (!talksObj.has("talks")) {
                throw SolverStop("lecture $lid locked (prev chapter not done?). ${talksRaw.body.take(200)}")
            }
            val talks = talksObj.getJSONArray("talks")
            for (ti in 0 until talks.length()) {
                val t = talks.getJSONObject(ti)
                // try* (JS) or exactly "try" (python); choice_question/choice_survey are story dialogues - skip.
                if (!t.optString("type").startsWith("try")) continue
                val tid = t.get("id").toString()
                val code = t.getJSONObject("body").getJSONArray("codes").getJSONObject(0)
                val lang = code.optString("lang", "javascript")
                var model = code.optString("model_answer", "")
                val src = code.optString("code", "")
                if (model.isEmpty()) model = src
                val payload: String
                val ph = code.optJSONArray("placeholders") ?: org.json.JSONArray()
                if (ph.length() > 0 && src.contains("fitbBlock")) {
                    val arr = org.json.JSONArray()
                    for (pi in 0 until ph.length()) {
                        val p = ph.getJSONObject(pi)
                        arr.put(JSONObject().put("name", p.getString("name")).put("code", p.optString("model_answer", "")))
                    }
                    payload = JSONObject().put("value", JSONObject().put("lang", lang).put("answers", arr)).toString()
                } else {
                    payload = JSONObject().put("value", JSONObject().put("lang", lang).put("answer", model)).toString()
                }
                tp.req("PUT", "$tpBase/api/study/students/lecture-talks/$tid", payload)
                pace.step(200)
            }
            tp.req("PUT", "$tpBase/api/study/students/lectures/$lid/complete", "{}")
            pace.step(300)
        }
    }
}
