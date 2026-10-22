package com.solver.app

import kotlinx.coroutines.ensureActive
import org.json.JSONArray
import org.json.JSONObject
import kotlin.coroutines.coroutineContext

/** Port of sprix-solver/solve.sh */
class SprixSolver(
    private val api: Api,
    private val log: (String) -> Unit,
    private val pace: Pace,
) {
    private val base = "https://egy.app.spx-learning-square.com"

    /** Full run with pre-loaded answers. Reports item-level progress + resume point. */
    suspend fun runWith(
        loginId: String,
        password: String,
        start: Int,
        chapters: Map<String, List<IdPair>>,
        tests: Map<String, List<IdPair>>,
        onProgress: (done: Int, total: Int, label: String) -> Unit = { _, _, _ -> },
        onResume: (nextStart: String) -> Unit = {},
    ) {
        log("[1/3] login...")
        val lr = api.req(
            "POST", "$base/api/v1/auth/login",
            JSONObject().put("login_id", loginId).put("password", password).toString(),
        )
        log("login http=${lr.code}")
        // Login/bootstrap delays are never scaled by Boost.
        pace.auth(1000)
        log("[2/3] verify...")
        log(api.req("GET", "$base/api/v1/auth/me").body.take(200))
        pace.auth(500)
        log("[3/3] solving units $start..24 ...")
        // Fetch curriculum once and build the plan (total item count for real progress).
        val cur0 = api.req("GET", "$base/api/v1/subjects/7/curriculum")
        if (!isJson(cur0.body)) throw SolverStop("curriculum non-JSON: ${cur0.body.take(200)}")
        val units0 = JSONObject(cur0.body).getJSONArray("data")
        val plan = mutableListOf<Pair<Int, JSONArray>>()
        for (u in start..24) {
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
                        val a = chapters[id]
                        if (a == null) doSimChapter(id) else doChapter(id, a)
                    }
                    "review" -> {
                        api.req("POST", "$base/api/v1/reviews/$id/complete", "{}")
                        log("  review $id done"); pace.step(300)
                    }
                    "test" -> doTest(id, tests[id] ?: throw SolverStop("test $id missing from answers"))
                }
                done++
                onProgress(done, total, "unit $u · $id")
            }
            // Next retry can skip this fully-done unit.
            onResume((u + 1).toString())
        }
        log("=== final status ===")
        val st = api.req("GET", "$base/api/v1/subjects/7/units")
        val arr = JSONObject(st.body).getJSONArray("data")
        for (i in 0 until arr.length()) {
            val x = arr.getJSONObject(i)
            log("${x.getInt("id")}: ${x.getInt("completed_items")}/${x.getInt("total_items")} (${x.get("progress_pct")}%)")
        }
        log("DONE.")
    }

    /** Simulation chapters have no question blocks: complete them directly. */
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

    private suspend fun doChapter(cid: String, ans: List<IdPair>) {
        var ok = 0
        for ((bid, oid) in ans) {
            val out = api.req(
                "POST", "$base/api/v1/chapters/$cid/answer",
                JSONObject().put("block_id", bid).put("selected_option_id", oid).toString(),
            )
            // NOTE: no hint_used field - server rejects it with 400. Retry is free.
            if (!out.body.contains("\"is_correct\":true")) {
                throw SolverStop("chapter $cid block $bid WRONG (retry with correct id)")
            }
            ok++
            pace.step(300)
        }
        log("  chapter $cid: $ok/${ans.size} correct -> complete:")
        log(api.req("POST", "$base/api/v1/chapters/$cid/complete", "{}").body)
        pace.step(300)
    }

    private suspend fun doTest(tid: String, ans: List<IdPair>) {
        // NOTE: start MUST be POST (GET returns 404 page not found)
        val raw = api.req("POST", "$base/api/v1/tests/$tid/start", "{}")
        if (!isJson(raw.body)) throw SolverStop("test $tid start failed: ${raw.body.take(200)}")
        val start = JSONObject(raw.body)
        // test_question ids are per-attempt: map question_id -> test_question_id from THIS start
        // (skip null entries - some accounts return extra null rows)
        val map = mutableMapOf<String, String>()
        val tqs = start.getJSONObject("data").getJSONArray("test_questions")
        for (i in 0 until tqs.length()) {
            val t = tqs.getJSONObject(i)
            if (!t.isNull("question_id") && !t.isNull("id")) {
                map[t.get("question_id").toString()] = t.get("id").toString()
            }
        }
        for ((qid, oid) in ans) {
            val tqid = map[qid.toString()] ?: throw SolverStop("test $tid q $qid not in this attempt!")
            api.req(
                "PUT", "$base/api/v1/tests/$tid/questions/$tqid/answer",
                JSONObject().put("selected_option_id", oid).toString(),
            )
            pace.step(250)
        }
        log("  test $tid submit:")
        log(api.req("POST", "$base/api/v1/tests/$tid/submit", "{}").body.take(300))
        pace.step(400)
    }
}
