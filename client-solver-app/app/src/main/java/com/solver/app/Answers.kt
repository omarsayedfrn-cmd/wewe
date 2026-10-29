package com.solver.app

import android.content.Context
import org.json.JSONObject

/** [block_id, option_id] for SPRIX chapters, [question_id, option_id] for tests. */
typealias IdPair = Pair<Long, Long>

object Answers {
    private fun readAsset(ctx: Context, name: String): JSONObject {
        return try {
            ctx.assets.open(name).use { ins ->
                JSONObject(ins.readBytes().toString(Charsets.UTF_8))
            }
        } catch (e: Exception) {
            android.util.Log.w("Answers", "asset $name unavailable: ${e.message}")
            JSONObject()
        }
    }

    private fun pairs(arr: org.json.JSONArray): List<IdPair> =
        List(arr.length()) { i ->
            val p = arr.getJSONArray(i)
            Pair(p.getLong(0), p.getLong(1))
        }

    fun sprixChapters(ctx: Context, asset: String = "sprix_answers.json"): Map<String, List<IdPair>> {
        val o = readAsset(ctx, asset).optJSONObject("chapters") ?: JSONObject()
        return o.keys().asSequence().associateWith { pairs(o.getJSONArray(it)) }
    }

    fun sprixTests(ctx: Context, asset: String = "sprix_answers.json"): Map<String, List<IdPair>> {
        val o = readAsset(ctx, asset).optJSONObject("tests") ?: JSONObject()
        return o.keys().asSequence().associateWith { pairs(o.getJSONArray(it)) }
    }

    data class QChoice(val qid: Long, val qtype: String, val choiceId: Long?, val answerCode: String?)

    data class QChapter(val type: String, val questions: List<QChoice>)

    fun qureo(ctx: Context, asset: String = "qureo_answers.json"): Map<String, QChapter> {
        val root = readAsset(ctx, asset)
        return root.keys().asSequence().associateWith { k ->
            val c = root.getJSONObject(k)
            val qs = c.getJSONArray("questions")
            QChapter(
                c.optString("type"),
                List(qs.length()) { i ->
                    val q = qs.getJSONObject(i)
                    QChoice(
                        q.getLong("qid"),
                        q.getString("qtype"),
                        if (q.has("choice_id")) q.getLong("choice_id") else null,
                        q.optString("answer_code", "").ifEmpty { null },
                    )
                },
            )
        }
    }
}
