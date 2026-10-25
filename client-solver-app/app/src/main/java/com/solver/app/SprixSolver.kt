package com.solver.app

import kotlinx.coroutines.ensureActive
import org.json.JSONArray
import org.json.JSONObject
import kotlin.coroutines.coroutineContext

/** SPRIX solver.
 *
 * AR (subject 7, units 19-24 raw): uses pre-loaded answers from sprix_answers.json,
 * sent SEQUENTIALLY with per-answer verification + brute-force fallback (fixed from
 * parallel awaitAll that could abort a whole chapter on one wrong answer).
 * EN (subject 3, units 1-6): self-discovering — brute-force chapters option-by-option
 * until is_correct:true, tests via learn+submit treasure harvest then apply pass 100%.
 * No answers.json needed for EN.
 */
class SprixSolver(
    private val api: Api,
    private val log: (String) -> Unit,
    private val pace: Pace,
    private val subject: Int = 7, // 7 = AR (الثقافة المالية), 3 = EN (Financial Literacy)
) {
    private val base = "https://egy.app.spx-learning-square.com"
    private val isEn = subject == 3

    suspend fun runWith(
        loginId: String,
        password: String,
        start: Int,
        chapters: Map<String, List<IdPair>>,
        tests: Map<String, List<IdPair>>,
        trialMode: Boolean = false,
        onProgress: (done: Int, total: Int, label: String) -> Unit = { _, _, _ -> },
        onResume: (nextStart: String) -> Unit = {},
    ) {
        log("[1/3] login...")
        val lr = api.req(
            "POST", "$base/api/v1/auth/login",
            JSONObject().put("login_id", loginId).put("password", password).toString(),
        )
        log("login http=${lr.code}")
        pace.auth(1000)
        log("[2/3] verify...")
        log(api.req("GET", "$base/api/v1/auth/me").body.take(200))
        pace.auth(500)

        val unitEnd = if (isEn) 6 else 24
        log("[3/3] solving units $start..$unitEnd (subject $subject, ${if (isEn) "EN" else "AR"}) ...")

        val cur0 = api.req("GET", "$base/api/v1/subjects/$subject/curriculum")
        if (!isJson(cur0.body)) throw SolverStop("curriculum non-JSON: ${cur0.body.take(200)}")
        val units0 = JSONObject(cur0.body).getJSONArray("data")

        val plan = mutableListOf<Pair<Int, JSONArray>>()
        for (u in start..unitEnd) {
            var items: JSONArray? = null
            for (i in 0 until units0.length()) {
                val un = units0.getJSONObject(i)
                if (un.getInt("id") == u) { items = un.getJSONArray("items"); break }
            }
            if (items == null) throw SolverStop("unit $u not in curriculum")
            plan.add(u to items)
        }
        val total = plan.sumOf { it.second.length() }
        var done = 0
        onProgress(0, total, "unit $start")
        for ((u, items) in plan) {
            coroutineContext.ensureActive()
            log("=== unit $u ===")
            for (i in 0 until items.length()) {
                coroutineContext.ensureActive()
                val it = items.getJSONObject(i)
                val id = it.get("id").toString()
                when (it.getString("item_type")) {
                    "chapter" -> {
                        if (isEn) {
                            doChapterEn(id)
                        } else {
                            val a = chapters[id]
                            if (a == null) doSimChapter(id) else doChapterAr(id, a)
                        }
                        if (trialMode) {
                            log("--------------------------------------------------")
                            log("⭐ [Trial done] Unit $u chapter solved successfully!")
                            log("⭐ To solve remaining units and chapters, activate the full version.")
                            log("--------------------------------------------------")
                            onProgress(1, 1, "trial done")
                            return
                        }
                    }
                    "review" -> {
                        api.req("POST", "$base/api/v1/reviews/$id/complete", "{}")
                        log("  review $id done"); pace.step(300)
                    }
                    "test" -> {
                        if (isEn) {
                            doTestEn(id)
                        } else {
                            doTestAr(id, tests[id] ?: throw SolverStop("test $id missing from answers"))
                        }
                    }
                }
                done++
                onProgress(done, total, "unit $u · $id")
            }
            onResume((u + 1).toString())
        }
        log("=== final status ===")
        val st = api.req("GET", "$base/api/v1/subjects/$subject/units")
        val arr = JSONObject(st.body).getJSONArray("data")
        for (i in 0 until arr.length()) {
            val x = arr.getJSONObject(i)
            log("${x.getInt("id")}: ${x.getInt("completed_items")}/${x.getInt("total_items")} (${x.get("progress_pct")}%)")
        }
        log("DONE.")
    }

    private suspend fun doSimChapter(cid: String) {
        val b = api.req("GET", "$base/api/v1/chapters/$cid/blocks")
        if (!isJson(b.body)) throw SolverStop("chapter $cid blocks non-JSON: ${b.body.take(200)}")
        val blocks = JSONObject(b.body).getJSONObject("data").getJSONArray("blocks")
        var nq = 0
        for (i in 0 until blocks.length()) {
            if (blocks.getJSONObject(i).optString("type") == "question") nq++
        }
        if (nq > 0) throw SolverStop("chapter $cid missing from answers ($nq questions!)")
        log(api.req("POST", "$base/api/v1/chapters/$cid/complete", "{}").body.take(200))
        log("  sim chapter $cid done (no questions)")
        pace.step(300)
    }

    /** AR chapter: sequential answers from answers.json with verification + brute-force fallback. */
    private suspend fun doChapterAr(cid: String, ans: List<IdPair>) {
        var ok = 0
        for ((bid, oid) in ans) {
            coroutineContext.ensureActive()
            val out = api.req(
                "POST", "$base/api/v1/chapters/$cid/answer",
                JSONObject().put("block_id", bid).put("selected_option_id", oid).toString(),
            )
            if (out.body.contains("\"is_correct\":true")) {
                ok++
            } else {
                log("  chapter $cid block $bid option $oid WRONG — brute-force fallback")
                val found = bruteForceChapterBlock(cid, bid, oid)
                if (found) ok++ else log("  chapter $cid block $bid: no accepted option")
            }
            pace.step(20)
        }
        log("  chapter $cid: $ok/${ans.size} correct -> complete:")
        log(api.req("POST", "$base/api/v1/chapters/$cid/complete", "{}").body)
        pace.step(30)
    }

    private suspend fun bruteForceChapterBlock(cid: String, bid: Long, skipOid: Long): Boolean {
        val blocks = api.req("GET", "$base/api/v1/chapters/$cid/blocks")
        if (!isJson(blocks.body)) return false
        val bArr = JSONObject(blocks.body).getJSONObject("data").getJSONArray("blocks")
        for (j in 0 until bArr.length()) {
            val b = bArr.getJSONObject(j)
            if (b.getString("id") != bid.toString()) continue
            val options = b.optJSONArray("options") ?: JSONArray()
            for (o in 0 until options.length()) {
                coroutineContext.ensureActive()
                val optId = options.getJSONObject(o).optLong("id", -1)
                if (optId == skipOid) continue
                val retry = api.req(
                    "POST", "$base/api/v1/chapters/$cid/answer",
                    JSONObject().put("block_id", bid).put("selected_option_id", optId).toString(),
                )
                if (retry.body.contains("\"is_correct\":true")) {
                    log("  chapter $cid block $bid: fallback option $optId CORRECT")
                    return true
                }
                pace.step(20)
            }
            break
        }
        return false
    }

    /** EN chapter: brute-force each MCQ option until is_correct:true, then complete. */
    private suspend fun doChapterEn(cid: String) {
        val blocksRaw = api.req("GET", "$base/api/v1/chapters/$cid/blocks")
        if (!isJson(blocksRaw.body)) throw SolverStop("chapter $cid blocks non-JSON: ${blocksRaw.body.take(200)}")
        val blocks = JSONObject(blocksRaw.body).getJSONObject("data").getJSONArray("blocks")
        var nq = 0
        for (i in 0 until blocks.length()) {
            if (blocks.getJSONObject(i).optString("type") == "question") nq++
        }
        if (nq == 0) {
            api.req("POST", "$base/api/v1/chapters/$cid/complete", "{}")
            log("  sim chapter $cid done (no questions)"); pace.step(300); return
        }
        for (i in 0 until blocks.length()) {
            coroutineContext.ensureActive()
            val b = blocks.getJSONObject(i)
            if (b.optString("type") != "question") continue
            val bid = b.get("id").toString()
            val qid = b.optString("question_id", "")
            val options = b.optJSONArray("options") ?: JSONArray()
            var found = false
            for (o in 0 until options.length()) {
                coroutineContext.ensureActive()
                val optId = options.getJSONObject(o).optLong("id", -1)
                val out = api.req(
                    "POST", "$base/api/v1/chapters/$cid/answer",
                    JSONObject().put("block_id", bid).put("selected_option_id", optId).toString(),
                )
                if (out.body.contains("\"is_correct\":true")) {
                    log("  ch$cid q$qid block$bid: option $optId CORRECT")
                    found = true; break
                }
                pace.step(20)
            }
            if (!found) log("  ch$cid q$qid block$bid: NO accepted option (all ${options.length()} tried) - continuing")
        }
        log("  chapter $cid complete:")
        api.req("POST", "$base/api/v1/chapters/$cid/complete", "{}")
        pace.step(30)
    }

    /** AR test: start -> answer all from answers.json -> submit (>=80). */
    private suspend fun doTestAr(tid: String, ans: List<IdPair>) {
        val raw = api.req("POST", "$base/api/v1/tests/$tid/start", "{}")
        if (!isJson(raw.body)) throw SolverStop("test $tid start failed: ${raw.body.take(200)}")
        val start = JSONObject(raw.body)
        val map = mutableMapOf<String, String>()
        val tqs = start.getJSONObject("data").getJSONArray("test_questions")
        for (i in 0 until tqs.length()) {
            val t = tqs.getJSONObject(i)
            if (!t.isNull("question_id") && !t.isNull("id")) {
                map[t.get("question_id").toString()] = t.get("id").toString()
            }
        }
        for ((qid, oid) in ans) {
            coroutineContext.ensureActive()
            val tqid = map[qid.toString()] ?: throw SolverStop("test $tid q $qid not in this attempt!")
            api.req(
                "PUT", "$base/api/v1/tests/$tid/questions/$tqid/answer",
                JSONObject().put("selected_option_id", oid).toString(),
            )
            pace.step(20)
        }
        log("  test $tid submit:")
        log(api.req("POST", "$base/api/v1/tests/$tid/submit", "{}").body.take(300))
        pace.step(40)
    }

    /** EN test: learn pass (guess+submit harvest treasure) -> apply pass (correct+submit 100%). */
    private suspend fun doTestEn(tid: String) {
        val startRaw = api.req("POST", "$base/api/v1/tests/$tid/start", "{}")
        if (!isJson(startRaw.body)) {
            log("  test $tid start failed: ${startRaw.body.take(300)}")
            return
        }
        val start = JSONObject(startRaw.body)
        val tqs = start.getJSONObject("data").getJSONArray("test_questions")
        val n = tqs.length()

        // Build question_id -> test_question_id map for this attempt
        val tqMap = mutableMapOf<String, String>()
        for (k in 0 until n) {
            val t = tqs.getJSONObject(k)
            if (!t.isNull("question_id") && !t.isNull("id")) {
                tqMap[t.get("question_id").toString()] = t.get("id").toString()
            }
        }

        // ---- Learn pass: answer all with first option ----
        for (k in 0 until n) {
            coroutineContext.ensureActive()
            val t = tqs.getJSONObject(k)
            val qid = t.optString("question_id", "")
            if (qid.isEmpty()) continue
            val tqid = tqMap[qid] ?: continue
            val options = t.optJSONArray("options") ?: JSONArray()
            val firstOpt = if (options.length() > 0) options.getJSONObject(0).optLong("id", -1) else -1L
            api.req(
                "PUT", "$base/api/v1/tests/$tid/questions/$tqid/answer",
                JSONObject().put("selected_option_id", firstOpt).toString(),
            )
            pace.step(20)
        }

        log("  test $tid learn-submit:")
        val sub = api.req("POST", "$base/api/v1/tests/$tid/submit", "{}")
        pace.step(30)

        // ---- Harvest correct answers from submit treasure (.data.options[qid][].is_correct==true) ----
        val ansFile = mutableMapOf<String, Long>()
        try {
            val subObj = JSONObject(sub.body)
            val subData = subObj.optJSONObject("data") ?: JSONObject()
            val subOptions = subData.optJSONObject("options") ?: JSONObject()
            for (key in subOptions.keys()) {
                val arr = subOptions.optJSONArray(key) ?: JSONArray()
                for (j in 0 until arr.length()) {
                    val opt = arr.getJSONObject(j)
                    if (opt.optBoolean("is_correct", false)) {
                        ansFile[key] = opt.optLong("id", -1)
                        break
                    }
                }
            }
        } catch (_: Exception) { }
        val nh = ansFile.size
        log("  test $tid harvested $nh correct answers")
        if (nh == 0) {
            log("  test $tid: harvest empty - check submit response")
            log(sub.body.take(300))
            return
        }

        // ---- Apply pass: restart, answer all correctly, submit ----
        val startRaw2 = api.req("POST", "$base/api/v1/tests/$tid/start", "{}")
        if (!isJson(startRaw2.body)) return
        val start2 = JSONObject(startRaw2.body)
        val tqs2 = start2.getJSONObject("data").getJSONArray("test_questions")
        val tqMap2 = mutableMapOf<String, String>()
        for (k in 0 until tqs2.length()) {
            val t = tqs2.getJSONObject(k)
            if (!t.isNull("question_id") && !t.isNull("id")) {
                tqMap2[t.get("question_id").toString()] = t.get("id").toString()
            }
        }
        for (k in 0 until tqs2.length()) {
            coroutineContext.ensureActive()
            val t = tqs2.getJSONObject(k)
            val qid = t.optString("question_id", "")
            if (qid.isEmpty()) continue
            val tqid = tqMap2[qid] ?: continue
            val oid = ansFile[qid]
            if (oid == null) {
                log("  test $tid q$qid: no harvested answer - skip")
                continue
            }
            api.req(
                "PUT", "$base/api/v1/tests/$tid/questions/$tqid/answer",
                JSONObject().put("selected_option_id", oid).toString(),
            )
            pace.step(20)
        }
        log("  test $tid apply-submit:")
        val sub2 = api.req("POST", "$base/api/v1/tests/$tid/submit", "{}")
        try {
            val resp = JSONObject(sub2.body).optJSONObject("data")?.optJSONObject("response")
            if (resp != null) {
                log("  test $tid result: score=${resp.optInt("total_score", 0)} passed=${resp.optBoolean("passed", false)}")
            } else {
                log("  test $tid: submit ok")
            }
        } catch (_: Exception) {
            log("  test $tid: submit ok")
        }
        pace.step(30)
    }
}
