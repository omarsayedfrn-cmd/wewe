package com.solver.app

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.google.android.material.button.MaterialButtonToggleGroup
import com.google.android.material.switchmaterial.SwitchMaterial
import com.google.android.material.textfield.TextInputLayout

class MainActivity : AppCompatActivity() {
    private var svc: SolverService? = null
    private var bound = false
    private var currentSession: String? = null
    // True while the user explicitly opened the login pane to add another session:
    // incoming log lines must NOT yank the UI back to the log pane.
    private var loginPinned = false

    private lateinit var loginPane: View
    private lateinit var logPane: View
    private lateinit var logView: TextView
    private lateinit var logScroll: ScrollView
    private lateinit var progress: ProgressBar
    private lateinit var progressText: TextView
    private lateinit var btnViewLog: Button
    private lateinit var btnRetry: Button
    private lateinit var startLayout: TextInputLayout
    private lateinit var sessionBar: LinearLayout
    private lateinit var boostSwitch: SwitchMaterial
    private lateinit var platformGroup: MaterialButtonToggleGroup
    private lateinit var langGroup: MaterialButtonToggleGroup
    // Boost is stored independently per engine (sprix/sprix_en/qureo/qureo_en/qureo2/qureo2_en).
    private val boostState = mutableMapOf(
        "sprix" to false, "sprix_en" to false,
        "qureo" to false, "qureo_en" to false,
        "qureo2" to false, "qureo2_en" to false
    )
    private var updatingBoost = false

    private val uiHandler = Handler(Looper.getMainLooper())
    private val refreshTick = object : Runnable {
        override fun run() {
            try {
                refreshChips()
                refreshProgressFromService()
            } catch (_: Exception) { }
            uiHandler.postDelayed(this, 2000)
        }
    }

    private val conn = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, b: IBinder?) {
            svc = (b as SolverService.LocalBinder).service()
            bound = true
            refreshState()
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            bound = false
            svc = null
        }
    }

    private val notifPerm = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        loginPane = findViewById(R.id.loginPane)
        logPane = findViewById(R.id.logPane)
        logView = findViewById(R.id.logView)
        logScroll = findViewById(R.id.logScroll)
        progress = findViewById(R.id.progress)
        progressText = findViewById(R.id.progressText)
        btnViewLog = findViewById(R.id.btnViewLog)
        btnRetry = findViewById(R.id.btnRetry)
        startLayout = findViewById(R.id.startLayout)
        sessionBar = findViewById(R.id.sessionBar)

        platformGroup = findViewById(R.id.platformGroup)
        langGroup = findViewById(R.id.langGroup)
        val inputStart: EditText = findViewById(R.id.inputStart)
        boostSwitch = findViewById(R.id.boostSwitch)
        val prefs = getSharedPreferences("solver", MODE_PRIVATE)
        boostState["sprix"] = prefs.getBoolean("boost_sprix", false)
        boostState["sprix_en"] = prefs.getBoolean("boost_sprix_en", false)
        boostState["qureo"] = prefs.getBoolean("boost_qureo", false)
        boostState["qureo_en"] = prefs.getBoolean("boost_qureo_en", false)
        boostState["qureo2"] = prefs.getBoolean("boost_qureo2", false)
        boostState["qureo2_en"] = prefs.getBoolean("boost_qureo2_en", false)
        // The switch only edits the Boost flag of the currently selected engine (platform+language).
        boostSwitch.setOnCheckedChangeListener { _, checked ->
            if (updatingBoost) return@setOnCheckedChangeListener
            val p = enginePlatform()
            boostState[p] = checked
            prefs.edit().putBoolean("boost_$p", checked).apply()
        }
        syncBoostSwitch()
        platformGroup.addOnButtonCheckedListener { _, _, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            applySelection(inputStart)
        }
        langGroup.addOnButtonCheckedListener { _, _, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            applySelection(inputStart)
        }

        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            notifPerm.launch(Manifest.permission.POST_NOTIFICATIONS)
        }

        findViewById<Button>(R.id.btnStart).setOnClickListener {
            val platform = enginePlatform()
            val boost = boostState[platform] == true
            val login = findViewById<EditText>(R.id.inputLogin).text.toString().trim()
            val pass = findViewById<EditText>(R.id.inputPassword).text.toString()
            val startRaw = inputStart.text.toString().trim()
            if (login.isEmpty() || pass.isEmpty()) {
                Toast.makeText(this, R.string.need_login, Toast.LENGTH_SHORT).show(); return@setOnClickListener
            }
            val okStart = when (platform) {
                "sprix" -> startRaw.toIntOrNull() in 1..6
                "sprix_en" -> startRaw.toIntOrNull() in 1..6
                "qureo" -> startRaw.toIntOrNull() in QureoCourse.QUREO.inputRange
                "qureo_en" -> startRaw.toIntOrNull() in QureoCourse.QUREO_EN.inputRange
                "qureo2" -> startRaw.toIntOrNull() in QureoCourse.QUREO2.inputRange
                else -> startRaw.toIntOrNull() in QureoCourse.QUREO2_EN.inputRange
            }
            if (!okStart) {
                Toast.makeText(this, R.string.need_start, Toast.LENGTH_SHORT).show(); return@setOnClickListener
            }
            // Map natural numbers (1-based) to raw platform ids; service works with raw ids only.
            val rawStart = when (platform) {
                "sprix" -> (18 + startRaw.toInt()).toString()
                "sprix_en" -> startRaw
                "qureo" -> QureoCourse.QUREO.rawOf(startRaw.toInt()) ?: startRaw
                "qureo_en" -> QureoCourse.QUREO_EN.rawOf(startRaw.toInt()) ?: startRaw
                "qureo2" -> QureoCourse.QUREO2.rawOf(startRaw.toInt()) ?: startRaw
                else -> QureoCourse.QUREO2_EN.rawOf(startRaw.toInt()) ?: startRaw
            }
            if (bound && svc != null) {
                // Fast path: service already alive -> new session (runs now or queues).
                val id = svc!!.startSession(platform, login, pass, rawStart, boost)
                if (svc!!.isQueued(id)) {
                    Toast.makeText(this, R.string.queued_msg, Toast.LENGTH_SHORT).show()
                }
                loginPinned = false
                switchTo(id)
                showLog()
            } else {
                // Service not bound yet: let onStartCommand create the session, pick it up on connect.
                val intent = Intent(this, SolverService::class.java)
                    .putExtra(SolverService.EXTRA_PLATFORM, platform)
                    .putExtra(SolverService.EXTRA_LOGIN, login)
                    .putExtra(SolverService.EXTRA_PASSWORD, pass)
                    .putExtra(SolverService.EXTRA_START, rawStart)
                    .putExtra(SolverService.EXTRA_BOOST, boost)
                ContextCompat.startForegroundService(this, intent)
                ensureBind()
                loginPinned = false
                showLog()
            }
        }

        btnViewLog.setOnClickListener { loginPinned = false; showLog() }
        findViewById<Button>(R.id.btnStop).setOnClickListener {
            currentSession?.let { svc?.stopSession(it) }
            refreshChips()
        }
        findViewById<Button>(R.id.btnStopAll).setOnClickListener {
            svc?.stopAll()
            refreshChips()
        }
        findViewById<Button>(R.id.btnBack).setOnClickListener { loginPinned = true; showLogin() }
        findViewById<Button>(R.id.btnNewSession).setOnClickListener { loginPinned = true; showLogin() }
        btnRetry.setOnClickListener {
            val s = svc
            val cur = currentSession
            if (s == null || cur == null) return@setOnClickListener
            val info = s.sessionInfo(cur)
            if (info == null) return@setOnClickListener
            if (info.running || info.queued) {
                Toast.makeText(this, R.string.retry_running, Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            val newId = s.retrySession(cur)
            if (newId != null) {
                if (s.isQueued(newId)) {
                    Toast.makeText(this, R.string.queued_msg, Toast.LENGTH_SHORT).show()
                }
                switchTo(newId)
            } else if (info.resumeStart == "done" || info.resumeStart.isEmpty()) {
                Toast.makeText(this, R.string.retry_nothing, Toast.LENGTH_SHORT).show()
            } else {
                Toast.makeText(this, R.string.retry_nopass, Toast.LENGTH_SHORT).show()
            }
        }

        findViewById<View>(R.id.txtFooterName)?.setOnLongClickListener {
            showAdminKeyDialog()
            true
        }
    }

    private fun showAdminKeyDialog() {
        val dialogView = layoutInflater.inflate(R.layout.dialog_admin_keygen, null)
        val inputCode = dialogView.findViewById<EditText>(R.id.inputClientDeviceCode)
        val outputKey = dialogView.findViewById<EditText>(R.id.outputGeneratedKey)
        val btnPaste = dialogView.findViewById<Button>(R.id.btnPasteCode)
        val btnMyCode = dialogView.findViewById<Button>(R.id.btnMyDeviceCode)
        val btnGenerate = dialogView.findViewById<Button>(R.id.btnDoGenerateKey)
        val btnCopy = dialogView.findViewById<Button>(R.id.btnCopyGeneratedKey)

        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager

        btnPaste.setOnClickListener {
            val clip = clipboard.primaryClip
            if (clip != null && clip.itemCount > 0) {
                inputCode.setText(clip.getItemAt(0).text?.toString()?.trim() ?: "")
            }
        }

        btnMyCode.setOnClickListener {
            inputCode.setText(LicenseEngine.getDeviceCode(this))
        }

        btnGenerate.setOnClickListener {
            val code = inputCode.text.toString().trim()
            if (code.isEmpty()) {
                Toast.makeText(this, "Enter or paste client device code", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            val key = LicenseEngine.generateLicenseKey(code)
            outputKey.setText(key)
        }

        btnCopy.setOnClickListener {
            val key = outputKey.text.toString().trim()
            if (key.isNotEmpty()) {
                val clip = android.content.ClipData.newPlainText("Activation Key", key)
                clipboard.setPrimaryClip(clip)
                Toast.makeText(this, "Key copied to clipboard!", Toast.LENGTH_SHORT).show()
            }
        }

        androidx.appcompat.app.AlertDialog.Builder(this)
            .setView(dialogView)
            .setNegativeButton("Close", null)
            .show()
    }

    private fun ensureBind() {
        if (!bound) {
            bindService(Intent(this, SolverService::class.java), conn, Context.BIND_AUTO_CREATE)
        }
    }

    /** Base platform chosen by the platform buttons (sprix/qureo/qureo2). */
    private fun selectedBase(): String = when (platformGroup.checkedButtonId) {
        R.id.btnQureo -> "qureo"
        R.id.btnQureo2 -> "qureo2"
        else -> "sprix"
    }

    /** Language chosen by the language buttons ("ar" or "en"). */
    private fun selectedLang(): String =
        if (langGroup.checkedButtonId == R.id.btnLangEn) "en" else "ar"

    /** Final engine key = platform + language (e.g. "qureo_en"), what the service runs. */
    private fun enginePlatform(): String {
        val base = selectedBase()
        return if (selectedLang() == "en") "${base}_en" else base
    }

    /** Reflect the chosen language+platform in the start field, hint and boost switch. */
    private fun applySelection(inputStart: EditText) {
        val en = selectedLang() == "en"
        val hint = when (selectedBase()) {
            "qureo" -> if (en) R.string.start_qureo_en_hint else R.string.start_qureo_hint
            "qureo2" -> if (en) R.string.start_qureo2_en_hint else R.string.start_qureo2_hint
            else -> if (en) R.string.start_sprix_en_hint else R.string.start_sprix_hint
        }
        inputStart.setText("1")
        startLayout.helperText = getString(hint)
        syncBoostSwitch()
    }

    /** Mirror the selected engine's Boost flag into the switch (no listener loop). */
    private fun syncBoostSwitch() {
        val p = enginePlatform()
        updatingBoost = true
        boostSwitch.isChecked = boostState[p] == true
        boostSwitch.text = getString(R.string.boost_label, p.uppercase())
        updatingBoost = false
    }

    override fun onStart() {
        super.onStart()
        ensureBind()
        uiHandler.post(refreshTick)
    }

    override fun onStop() {
        uiHandler.removeCallbacks(refreshTick)
        if (bound) {
            try { svc?.detach(currentSession) } catch (_: Exception) { }
            try { unbindService(conn) } catch (_: Exception) { }
            bound = false
            svc = null
        }
        super.onStop()
    }

    private fun showLog() {
        loginPane.visibility = View.GONE
        logPane.visibility = View.VISIBLE
        refreshChips()
        refreshProgressFromService()
    }

    private fun showLogin() {
        logPane.visibility = View.GONE
        loginPane.visibility = View.VISIBLE
        // Offer a way back to existing sessions.
        btnViewLog.visibility = if (svc != null && svc!!.sessionCount > 0) View.VISIBLE else View.GONE
    }

    private fun refreshState() {
        val s = svc ?: run { showLogin(); return }
        val all = s.allSessions()
        if (all.isEmpty()) {
            showLogin()
            return
        }
        // Keep selection if possible, else pick the latest running/queued session.
        if (currentSession == null || s.sessionInfo(currentSession!!) == null) {
            currentSession = all.lastOrNull { it.running || it.queued }?.id ?: all.last().id
        }
        currentSession?.let { switchTo(it) }
        showLog()
    }

    private fun switchTo(sessionId: String) {
        val s = svc ?: return
        // User explicitly views a session -> stop pinning the login pane.
        loginPinned = false
        // Detach previous live feed.
        currentSession?.let { try { s.detach(it) } catch (_: Exception) { } }
        currentSession = sessionId
        logView.text = ""
        resetProgressUI()
        s.attach(
            sessionId,
            { line -> appendLog(sessionId, line) },
            { done, total, label -> runOnUiThread { updateProgressUI(done, total, label) } },
        )
        refreshChips()
        refreshProgressFromService()
    }

    private fun resetProgressUI() {
        progress.isIndeterminate = true
        progressText.text = getString(R.string.progress_starting)
        btnRetry.visibility = View.GONE
    }

    /** Raw platform ids -> friendly numbers: QUREO #1..54, QUREO2 #1..25, SPRIX #1..6. */
    private fun friendlyStart(platform: String, start: String): String = when (platform) {
        "qureo" -> QureoCourse.QUREO.displayStart(start)
        "qureo_en" -> QureoCourse.QUREO_EN.displayStart(start)
        "qureo2" -> QureoCourse.QUREO2.displayStart(start)
        "qureo2_en" -> QureoCourse.QUREO2_EN.displayStart(start)
        "sprix" -> start.toIntOrNull()?.let { (it - 18).takeIf { n -> n in 1..6 } }?.let { "#$it" } ?: start
        "sprix_en" -> start.toIntOrNull()?.takeIf { n -> n in 1..6 }?.let { "#$it" } ?: start
        else -> start
    }

    private fun updateProgressUI(done: Int, total: Int, label: String) {
        try {
            if (total > 0) {
                progress.isIndeterminate = false
                progress.max = total
                progress.progress = done.coerceIn(0, total)
                val pct = done * 100 / total
                progressText.text = "$done/$total · $label ($pct%)"
            } else {
                progress.isIndeterminate = true
                progressText.text = label.ifEmpty { getString(R.string.progress_starting) }
            }
        } catch (_: Exception) { }
    }

    private fun refreshProgressFromService() {
        val s = svc ?: return
        val cur = currentSession ?: return
        runOnUiThread {
            try {
                val info = s.sessionInfo(cur) ?: return@runOnUiThread
                if (info.queued) {
                    progress.isIndeterminate = true
                    val pos = s.queuePosition(cur)
                    progressText.text = "⏳ queued (position $pos) — max ${SolverService.MAX_PARALLEL} parallel"
                } else {
                    updateProgressUI(info.progressDone, info.progressTotal, info.progressLabel)
                }
                btnRetry.visibility = if (s.canRetry(cur)) View.VISIBLE else View.GONE
            } catch (_: Exception) { }
        }
    }

    private fun refreshChips() {
        val s = svc ?: return
        runOnUiThread {
            try {
                val all = s.allSessions()
                sessionBar.removeAllViews()
                if (all.isEmpty()) {
                    progress.isIndeterminate = false
                    return@runOnUiThread
                }
                for (info in all) {
                    val b = Button(this, null, android.R.attr.buttonStyleSmall).apply {
                        val dot = when {
                            info.queued -> "⏳ "
                            info.running -> "● "
                            else -> "○ "
                        }
                        text = (if (info.boost) "⚡ " else "") + dot + info.platform.uppercase() + " " +
                            friendlyStart(info.platform, info.start)
                        textSize = 12f
                        isAllCaps = false
                    }
                    val selected = info.id == currentSession
                    if (selected) {
                        b.backgroundTintList = ContextCompat.getColorStateList(this, R.color.gold)
                        b.setTextColor(ContextCompat.getColor(this, R.color.terminal_bg))
                    } else {
                        b.backgroundTintList = ContextCompat.getColorStateList(this, R.color.burgundy)
                        b.setTextColor(ContextCompat.getColor(this, R.color.cream))
                    }
                    b.alpha = if (info.running || info.queued) 1.0f else 0.65f
                    b.setOnClickListener { switchTo(info.id) }
                    sessionBar.addView(b)
                }
                currentSession?.let { btnRetry.visibility = if (s.canRetry(it)) View.VISIBLE else View.GONE }
                btnViewLog.visibility = View.VISIBLE
            } catch (_: Exception) { }
        }
    }

    private fun appendLog(sessionId: String, line: String) {
        runOnUiThread {
            try {
                if (sessionId != currentSession) {
                    // Another session's line: just refresh its dot, don't interleave logs.
                    refreshChips()
                    return@runOnUiThread
                }
                // Never yank the user out of the login pane while they type a new session.
                if (!loginPinned && logPane.visibility != View.VISIBLE) showLog()
                logView.append(line + "\n")
                logScroll.post { logScroll.fullScroll(View.FOCUS_DOWN) }
                if (line.contains("finished") || line.startsWith("STOP") ||
                    line.startsWith("ERROR") || line.startsWith("DONE") ||
                    line.startsWith("⏳") || line.startsWith("▶")
                ) {
                    refreshChips()
                    refreshProgressFromService()
                }
            } catch (_: Exception) { }
        }
    }
}
