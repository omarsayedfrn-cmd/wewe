package com.solver.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.RingtoneManager
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

/** Lightweight snapshot of a run session for the UI. */
data class SessionInfo(
    val id: String,
    val platform: String, // "sprix" | "qureo" | "qureo2"
    val login: String,
    val start: String,
    val running: Boolean,
    val queued: Boolean = false,
    val progressDone: Int = 0,
    val progressTotal: Int = 0,
    val progressLabel: String = "",
    val resumeStart: String = start,
    val finished: Boolean = false,
    val result: String = "",
    val boost: Boolean = false,
)

/**
 * Multi-session foreground service: up to MAX_PARALLEL solver runs at once,
 * extras wait in a FIFO queue. Each session has its own logs + progress.
 */
class SolverService : Service() {
    companion object {
        const val EXTRA_PLATFORM = "platform" // "sprix" | "qureo" | "qureo2"
        const val EXTRA_LOGIN = "login"
        const val EXTRA_PASSWORD = "password"
        const val EXTRA_START = "start"
        const val EXTRA_BOOST = "boost"
        const val MAX_PARALLEL = 3
        const val MAX_AUTO_RETRY = 3
        private const val CH = "solver"
        private const val CH_DONE = "solver_done"
        private const val NID = 1
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val seq = AtomicInteger(0)
    private val notifSeq = AtomicInteger(0)

    private data class Session(
        val seqNo: Int,
        val id: String,
        val platform: String,
        val login: String,
        var password: String, // in-memory only (queue + retry), never logged or persisted
        val start: String,
        val boost: Boolean = false,
        @Volatile var resumeStart: String = start,
        var job: Job? = null,
        var queued: Boolean = false,
        var finished: Boolean = false,
        var result: String = "",
        var autoRetries: Int = 0, // network auto-retries used (max 3)
        val logs: MutableList<String> = mutableListOf(),
        @Volatile var progressDone: Int = 0,
        @Volatile var progressTotal: Int = 0,
        @Volatile var progressLabel: String = "",
    ) {
        val running: Boolean get() = job?.isActive == true
    }

    private val sessions = ConcurrentHashMap<String, Session>()
    // One live listener per session (the UI shows a single session at a time).
    private val listeners = ConcurrentHashMap<String, (String) -> Unit>()
    private val progressListeners = ConcurrentHashMap<String, (Int, Int, String) -> Unit>()
    @Volatile private var lastNotif = 0L
    // Partial wake lock keeps CPU/network alive while sessions run in background (anti-Doze).
    private var wakeLock: android.os.PowerManager.WakeLock? = null

    /** Hold the wake lock iff any session runs or waits; release otherwise. */
    private fun updateWakeLock() {
        try {
            val need = sessions.values.any { it.running || it.queued }
            if (need) {
                if (wakeLock?.isHeld != true) {
                    val pm = getSystemService(POWER_SERVICE) as android.os.PowerManager
                    wakeLock = pm.newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK, "Solver::run").apply {
                        setReferenceCounted(false)
                        acquire()
                    }
                }
            } else {
                wakeLock?.let { if (it.isHeld) it.release() }
                wakeLock = null
            }
        } catch (_: Exception) { }
    }

    inner class LocalBinder : Binder() {
        fun service() = this@SolverService
    }

    override fun onBind(intent: Intent?): IBinder = LocalBinder()

    /** True if at least one session is still running. */
    val running: Boolean get() = sessions.values.any { it.running }
    val runningCount: Int get() = sessions.values.count { it.running }
    val queuedCount: Int get() = sessions.values.count { it.queued }
    val sessionCount: Int get() = sessions.size

    fun isRunning(sessionId: String): Boolean = sessions[sessionId]?.running == true
    fun isQueued(sessionId: String): Boolean = sessions[sessionId]?.queued == true

    private fun Session.toInfo() = SessionInfo(
        id, platform, login, start, running, queued,
        progressDone, progressTotal, progressLabel, resumeStart, finished, result, boost,
    )

    @Synchronized
    fun sessionInfo(sessionId: String): SessionInfo? = sessions[sessionId]?.toInfo()

    @Synchronized
    fun allSessions(): List<SessionInfo> =
        sessions.values.sortedBy { it.seqNo }.map { it.toInfo() }

    @Synchronized
    fun sessionLogs(sessionId: String): List<String> = sessions[sessionId]?.logs?.toList() ?: emptyList()

    /**
     * Start a new session. Launches immediately if fewer than MAX_PARALLEL run,
     * otherwise waits in a FIFO queue. Returns the session id.
     * Never touches other sessions' jobs or logs.
     */
    @Synchronized
    fun startSession(platform: String, login: String, password: String, start: String, boost: Boolean = false): String {
        startFg()
        val n = seq.incrementAndGet()
        val id = "$platform-$start-$n"

        if (!LicenseEngine.isActivated(this) && LicenseEngine.isTrialUsed(this)) {
            val s = Session(
                seqNo = n, id = id, platform = platform, login = login, password = "",
                start = start, finished = true, result = "TRIAL_CONSUMED",
                logs = mutableListOf("❌ لقد استهلكت تجربتك المجانية بالفعل. يرجى إدخال كود التفعيل للبدء في حل باقي الفصول.")
            )
            sessions[id] = s
            push(id, "❌ لقد استهلكت تجربتك المجانية بالفعل. يرجى إدخال كود التفعيل للبدء في حل باقي الفصول.")
            return id
        }

        val s = Session(seqNo = n, id = id, platform = platform, login = login, password = password, start = start, boost = boost)
        sessions[id] = s
        push(id, "▶ $platform starting… login=$login start=$start [$id]")
        if (boost) push(id, getString(R.string.boost_on_log, Pace.fmtScale(Pace.scaleFor(platform))))
        if (runningCount < MAX_PARALLEL) {
            launchJob(s)
        } else {
            s.queued = true
            push(id, "⏳ queued (position ${queuePosition(id)}) — max $MAX_PARALLEL parallel")
        }
        return id
    }

    /** 1-based position inside the waiting queue. */
    @Synchronized
    fun queuePosition(sessionId: String): Int {
        val q = sessions.values.filter { it.queued }.sortedBy { it.seqNo }
        return q.indexOfFirst { it.id == sessionId } + 1
    }

    /** Retry a finished session from its last completed point. Null = not retryable. */
    @Synchronized
    fun retrySession(oldId: String): String? {
        val old = sessions[oldId] ?: return null
        if (old.running || old.queued) return null
        if (old.password.isEmpty()) return null
        val ns = old.resumeStart
        if (ns.isEmpty() || ns == "done") return null
        if (!isValidStart(old.platform, ns)) return null
        startFg()
        val n = seq.incrementAndGet()
        val id = "${old.platform}-$ns-$n"
        val s = Session(seqNo = n, id = id, platform = old.platform, login = old.login, password = old.password, start = ns, boost = old.boost)
        sessions[id] = s
        push(id, "↻ retry from $ns (after [$oldId]) …")
        if (old.boost) push(id, getString(R.string.boost_on_log, Pace.fmtScale(Pace.scaleFor(old.platform))))
        if (runningCount < MAX_PARALLEL) {
            launchJob(s)
        } else {
            s.queued = true
            push(id, "⏳ queued (position ${queuePosition(id)}) — max $MAX_PARALLEL parallel")
        }
        return id
    }

    /** Whether the retry button should be shown for this session. */
    @Synchronized
    fun canRetry(sessionId: String): Boolean {
        val s = sessions[sessionId] ?: return false
        if (s.running || s.queued || !s.finished) return false
        if (s.password.isEmpty()) return false
        val ns = s.resumeStart
        if (ns.isEmpty() || ns == "done") return false
        return isValidStart(s.platform, ns)
    }

    private fun isValidStart(platform: String, start: String): Boolean = when (platform) {
        "sprix" -> start.toIntOrNull() in 19..24
        "qureo" -> start.matches(QureoCourse.QUREO.startRegex)
        "qureo2" -> start.matches(QureoCourse.QUREO2.startRegex)
        else -> false
    }

    private fun launchJob(s: Session) {
        s.queued = false
        updateWakeLock()
        s.job = scope.launch {
            val log: (String) -> Unit = { push(s.id, it) }
            // One pacing governor per session; survives network auto-retries so
            // the rate-limit counter is not reset between attempts.
            val pace = Pace(s.boost, s.platform, log)
            while (true) {
                // Resume point (updated live by solvers); fall back to original start.
                val fromRaw = s.resumeStart.takeIf { it.isNotEmpty() && it != "done" } ?: s.start
                val from = fromRaw.toIntOrNull() ?: s.start.toInt()
                try {
                    if (s.platform == "sprix") runSprix(s.login, s.password, from, s.id, pace)
                    else runQureo(s.platform, s.login, s.password, from, s.id, pace)
                    s.result = "DONE"
                    break
                } catch (e: CancellationException) {
                    push(s.id, "STOPPED by user.")
                    s.result = "STOPPED"
                    break
                } catch (e: SolverStop) {
                    push(s.id, "STOP: ${e.message}")
                    s.result = "STOPPED"
                    break
                } catch (e: java.io.IOException) {
                    // Transient network loss (background Doze, tunnel drop...): self-heal from resume point.
                    s.autoRetries++
                    if (s.autoRetries > MAX_AUTO_RETRY || s.password.isEmpty()) {
                        push(s.id, "ERROR: connection failed (${e.message?.take(150)})")
                        s.result = "ERROR"
                        break
                    }
                    push(s.id, "↻ connection lost (${e.message?.take(120)}) — auto-retry ${s.autoRetries}/$MAX_AUTO_RETRY from ${s.resumeStart}…")
                    try {
                        kotlinx.coroutines.delay(5000)
                    } catch (_: CancellationException) {
                        push(s.id, "STOPPED by user.")
                        s.result = "STOPPED"
                        break
                    }
                    // loop: relaunch from resumeStart (attempts are free, best score is kept)
                } catch (e: Exception) {
                    push(s.id, "ERROR: ${e.message}")
                    s.result = "ERROR"
                    break
                }
            }
            s.finished = true
            push(s.id, "--- finished [${s.id}] ---")
            onSessionFinished(s)
        }
    }

    /** Promote queued sessions while slots are free. Caller must hold the monitor. */
    private fun pumpQueueLocked() {
        while (runningCount < MAX_PARALLEL) {
            val next = sessions.values.filter { it.queued && !it.finished }.minByOrNull { it.seqNo } ?: break
            next.queued = false
            push(next.id, "▶ dequeued — starting now [${next.id}]")
            launchJob(next)
        }
    }

    private fun onSessionFinished(s: Session) {
        try { alertFinished(s) } catch (_: Exception) { }
        synchronized(this) { pumpQueueLocked() }
        updateWakeLock()
        stopSelfIfIdle()
    }

    /** Sound + vibration + a separate (non-ongoing) notification per finished session. */
    private fun alertFinished(s: Session) {
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            RingtoneManager.getRingtone(applicationContext, uri)?.play()
        } catch (_: Exception) { }
        try {
            if (Build.VERSION.SDK_INT >= 31) {
                getSystemService(VibratorManager::class.java)?.defaultVibrator
                    ?.vibrate(VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                val v = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (Build.VERSION.SDK_INT >= 26) {
                    v?.vibrate(VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION") v?.vibrate(400)
                }
            }
        } catch (_: Exception) { }
        try {
            val nm = getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(
                    NotificationChannel(CH_DONE, getString(R.string.notif_channel_done), NotificationManager.IMPORTANCE_HIGH),
                )
            }
            val pct = if (s.progressTotal > 0) " (${s.progressDone * 100 / s.progressTotal}%)" else ""
            val n: Notification = NotificationCompat.Builder(this, CH_DONE)
                .setContentTitle(getString(R.string.session_done_title, s.id))
                .setContentText("${s.platform} ${s.start} → ${s.result}$pct".take(200))
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setAutoCancel(true)
                .build()
            nm.notify(1000 + notifSeq.incrementAndGet(), n)
        } catch (_: Exception) { }
    }

    fun stopSession(sessionId: String) {
        val s = sessions[sessionId] ?: return
        if (s.queued) {
            // Cancel while still waiting: drop it outright.
            synchronized(this) {
                sessions.remove(sessionId)
                listeners.remove(sessionId)
                progressListeners.remove(sessionId)
            }
            scope.launch { stopSelfIfIdle() }
            return
        }
        s.job?.cancel()
        // "STOPPED by user." + "--- finished ---" are pushed by the coroutine's end path,
        // which also pumps the queue.
        updateWakeLock()
        scope.launch { stopSelfIfIdle() }
    }

    /** Legacy single-session stop: stops everything (kept for compat). */
    fun stopRun() = stopAll()

    fun stopAll() {
        synchronized(this) {
            sessions.values.filter { it.queued }.map { it.id }.forEach {
                sessions.remove(it); listeners.remove(it); progressListeners.remove(it)
            }
            sessions.values.forEach { it.job?.cancel() }
        }
        updateWakeLock()
        scope.launch { stopSelfIfIdle() }
    }

    @Synchronized
    fun clearSession(sessionId: String) {
        // Remove a finished session's history so the chips bar stays clean.
        val s = sessions[sessionId]
        if (s != null && !s.running && !s.queued) {
            sessions.remove(sessionId)
            listeners.remove(sessionId)
            progressListeners.remove(sessionId)
        }
    }

    @Synchronized
    fun clearLogs() {
        // Legacy: clear finished sessions only, never kill running/queued ones.
        val dead = sessions.values.filter { !it.running && !it.queued }.map { it.id }
        dead.forEach { sessions.remove(it); listeners.remove(it); progressListeners.remove(it) }
    }

    /** Attach live log + progress listeners to one session (replays history first). */
    @Synchronized
    fun attach(
        sessionId: String,
        onLog: (String) -> Unit,
        onProgress: (done: Int, total: Int, label: String) -> Unit = { _, _, _ -> },
    ) {
        listeners[sessionId] = onLog
        progressListeners[sessionId] = onProgress
        val s = sessions[sessionId] ?: return
        s.logs.forEach(onLog)
        if (s.progressTotal > 0) onProgress(s.progressDone, s.progressTotal, s.progressLabel)
    }

    /** Legacy attach: attaches to the most recent session (if any). */
    @Synchronized
    fun attach(l: (String) -> Unit) {
        val latest = sessions.values.sortedBy { it.seqNo }.lastOrNull() ?: return
        attach(latest.id, l)
    }

    fun detach(sessionId: String? = null) {
        if (sessionId == null) { listeners.clear(); progressListeners.clear() }
        else { listeners.remove(sessionId); progressListeners.remove(sessionId) }
    }

    @Synchronized
    fun push(sessionId: String, s: String) {
        sessions[sessionId]?.logs?.add(s)
        listeners[sessionId]?.invoke(s)
        refreshOngoingNotif(sessionId, s)
    }

    fun updateProgress(sessionId: String, done: Int, total: Int, label: String) {
        sessions[sessionId]?.let {
            it.progressDone = done
            it.progressTotal = total
            it.progressLabel = label
        }
        progressListeners[sessionId]?.invoke(done, total, label)
        // Ongoing notification is throttled inside notifyWith.
        refreshOngoingNotif(sessionId, "$done/$total · $label")
    }

    private fun refreshOngoingNotif(sessionId: String, line: String) {
        val rc = runningCount
        val qc = queuedCount
        val title = if (rc > 0) getString(R.string.notif_title_multi, rc) else getString(R.string.notif_title)
        val text = (if (qc > 0) "+$qc queued · " else "") + "[$sessionId] ${line.take(160)}"
        notifyWith(title, text)
    }

    // ---- intent entry: each start command = one new session (possibly queued) ----
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // STICKY: if the system kills us in background, restart (sessions self-heal via auto-retry).
        if (intent == null) { startFg(); updateWakeLock(); stopSelfIfIdle(); return START_STICKY }
        val platform = intent.getStringExtra(EXTRA_PLATFORM) ?: "sprix"
        val login = intent.getStringExtra(EXTRA_LOGIN) ?: ""
        val password = intent.getStringExtra(EXTRA_PASSWORD) ?: ""
        val start = intent.getStringExtra(EXTRA_START) ?: ""
        val boost = intent.getBooleanExtra(EXTRA_BOOST, false)
        if (login.isEmpty()) { stopSelfIfIdle(); return START_STICKY }
        startSession(platform, login, password, start, boost)
        return START_STICKY
    }

    private fun stopSelfIfIdle() {
        if (sessions.values.none { it.running || it.queued }) {
            // Keep finished logs for the UI, but allow the process to stop.
            try { stopSelf() } catch (_: Exception) { }
        }
    }

    private suspend fun runSprix(login: String, password: String, start: Int, sessionId: String, pace: Pace) {
        val api = Api(
            mapOf(
                "User-Agent" to UA,
                "Accept" to "application/json, text/plain, */*",
                "Content-Type" to "application/json",
                "Referer" to "https://egy.app.spx-learning-square.com/subjects/7/curriculum",
                "Accept-Language" to "en-US,en;q=0.9",
            ),
            pace = pace,
        )
        val log: (String) -> Unit = { push(sessionId, it) }
        val trialMode = !LicenseEngine.isActivated(this)
        SprixSolver(api, log, pace).runWith(
            login, password, start,
            Answers.sprixChapters(this), Answers.sprixTests(this),
            trialMode = trialMode,
            onProgress = { d, t, l -> updateProgress(sessionId, d, t, l) },
            onResume = { nx -> sessions[sessionId]?.resumeStart = nx },
        )
        if (trialMode) {
            LicenseEngine.setTrialUsed(this)
        }
    }

    private suspend fun runQureo(platform: String, login: String, password: String, start: Int, sessionId: String, pace: Pace) {
        val course = QureoCourse.of(platform)
        val asset = if (platform == "qureo2") "qureo2_answers.json" else "qureo_answers.json"
        val store = CookieStore()
        val portal = Api(
            mapOf(
                "User-Agent" to UA,
                "Accept" to "application/json",
                "Content-Type" to "application/json",
                "Origin" to "https://me-portal.qureo.education",
                "Referer" to "https://me-portal.qureo.education/login",
                "Accept-Language" to "en-US,en;q=0.9",
            ), store, pace,
        )
        val tp = Api(
            mapOf(
                "User-Agent" to UA,
                "Accept" to "*/*",
                "Content-Type" to "application/json",
                "Origin" to "https://me-tp.qureo.education",
                "Referer" to "https://me-tp.qureo.education/",
                "Accept-Language" to "en-US,en;q=0.9",
            ), store, pace,
        )
        val log: (String) -> Unit = { push(sessionId, it) }
        val trialMode = !LicenseEngine.isActivated(this)
        QureoSolver(portal, tp, store, log, pace, course).runWith(
            login, password, start, Answers.qureo(this, asset),
            trialMode = trialMode,
            onProgress = { d, t, l -> updateProgress(sessionId, d, t, l) },
            onResume = { nx -> sessions[sessionId]?.resumeStart = nx },
        )
        if (trialMode) {
            LicenseEngine.setTrialUsed(this)
        }
    }

    private fun startFg() {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(CH, getString(R.string.notif_channel), NotificationManager.IMPORTANCE_LOW),
            )
        }
        val n: Notification = NotificationCompat.Builder(this, CH)
            .setContentTitle(getString(R.string.notif_title))
            .setContentText(getString(R.string.notif_text))
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .build()
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(NID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(NID, n)
            }
        } catch (_: Exception) {
            // Already in foreground: ignore.
        }
    }

    private fun notifyWith(title: String, text: String) {
        try {
            val now = System.currentTimeMillis()
            if (now - lastNotif < 1500) return
            lastNotif = now
            val n: Notification = NotificationCompat.Builder(this, CH)
                .setContentTitle(title)
                .setContentText(text)
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setOngoing(true)
                .build()
            getSystemService(NotificationManager::class.java).notify(NID, n)
        } catch (_: Exception) { }
    }

    override fun onDestroy() {
        try {
            wakeLock?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) { }
        wakeLock = null
        scope.cancel()
        super.onDestroy()
    }
}
