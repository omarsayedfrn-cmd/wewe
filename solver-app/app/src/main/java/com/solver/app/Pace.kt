package com.solver.app

import kotlinx.coroutines.delay
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.random.Random

/**
 * Per-session pacing governor for Boost mode.
 *
 * Boost scales ONLY solver work-loop delays (lectures/questions/tests) by a
 * platform factor with random jitter and a hard floor. Login/bootstrap delays
 * are never scaled ([auth]). Any HTTP 429 escalates the scale, cools down
 * 15-25s and lets Api retry; after [MAX_INCIDENTS] hits boost disables itself
 * for the rest of the session and pacing returns to normal.
 *
 * Evidence: the 46-student SPRIX batch ran with SLEEP_SCALE=0.3 and 8 workers
 * with zero 429s, so SPRIX starts at 0.3. QUREO has no batch evidence -> 0.4.
 */
class Pace(
    val enabled: Boolean,
    platform: String,
    private val log: (String) -> Unit,
) {
    companion object {
        const val SCALE_SPRIX = 0.03
        const val SCALE_QUREO = 0.04
        const val FLOOR_MS = 20L
        const val JITTER = 0.20
        const val MAX_INCIDENTS = 3
        const val BACKOFF_BASE_MS = 15_000L

        fun scaleFor(platform: String): Double =
            if (platform == "sprix" || platform == "sprix_en") SCALE_SPRIX else SCALE_QUREO

        /** "0.3" / "0.6" / "1" — locale-safe display for logs. */
        fun fmtScale(v: Double): String = ((v * 100).roundToInt() / 100.0).toString()
    }

    private val rnd = Random(System.nanoTime())

    @Volatile
    var effectiveScale: Double = if (enabled) scaleFor(platform) else 1.0
        private set

    @Volatile
    var incidents: Int = 0
        private set

    @Volatile
    var disabled: Boolean = false
        private set

    /** Scaled delay for solver work-loop steps (jittered, floored). */
    suspend fun step(baseMs: Long) {
        if (!enabled || disabled) {
            delay(baseMs)
            return
        }
        val jittered = baseMs * effectiveScale * (1.0 - JITTER + rnd.nextDouble() * JITTER * 2.0)
        delay(max(FLOOR_MS, jittered.toLong()))
    }

    /** Unscaled delay for login / session bootstrap steps (never boosted). */
    suspend fun auth(baseMs: Long) = delay(baseMs)

    /** Called by Api on HTTP 429 only: escalate, cool down, maybe disable. */
    suspend fun onRateLimit(attempt: Int) {
        if (enabled && !disabled) {
            incidents++
            if (incidents >= MAX_INCIDENTS) {
                disabled = true
                effectiveScale = 1.0
                log("⚠ rate limit ×$incidents — Boost auto-disabled, normal pacing")
            } else {
                effectiveScale = minOf(1.0, effectiveScale + 0.2)
                log("⚠ HTTP 429 — rate guard: Boost slowed to ×${fmtScale(effectiveScale)}")
            }
        }
        val backoff = BACKOFF_BASE_MS + attempt * 5_000L + rnd.nextLong(0L, 5_000L)
        log("⏸ rate guard: cooling down ${backoff / 1000}s")
        delay(backoff)
    }

    /** Called on HTTP 403 (locked/forbidden): log but NO cooldown, fail fast. */
    suspend fun onForbidden(context: String) {
        if (enabled) log("⛔ $context: HTTP 403 (locked/forbidden) — not retrying")
    }
}
