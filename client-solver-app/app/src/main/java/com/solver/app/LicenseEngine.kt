package com.solver.app

import android.annotation.SuppressLint
import android.content.Context
import android.provider.Settings
import java.security.MessageDigest
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

object LicenseEngine {
    // Secret master key used to sign device codes into activation keys.
    private const val MASTER_SECRET = "OmarSayed#Solver2024!KeyGen_Secret99"
    private const val DEVICE_SALT = "OMAR_DEVICE_SALT_V1"
    private const val PREFS_NAME = "solver_license"
    private const val PREF_KEY = "activation_key"

    // Master override key in case developer needs emergency unlock on any device
    const val MASTER_OVERRIDE_KEY = "ACT-OMAR-MASTER-2024"

    /**
     * Generates a clean, human-readable 8-char device code like: OM-XXXX-XXXX
     */
    @SuppressLint("HardwareIds")
    fun getDeviceCode(context: Context): String {
        val androidId = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ANDROID_ID
        ) ?: "UNKNOWN_DEVICE_ID"

        val hash = sha256("$androidId:$DEVICE_SALT")
        val clean = hash.take(8).uppercase()
        return "OM-${clean.substring(0, 4)}-${clean.substring(4, 8)}"
    }

    /**
     * Generates an activation license key for a given device code: ACT-XXXX-XXXX-XXXX
     */
    fun generateLicenseKey(rawDeviceCode: String): String {
        val cleanCode = rawDeviceCode.trim().uppercase()
        val hmac = hmacSha256(cleanCode, MASTER_SECRET)
        val cleanHmac = hmac.take(12).uppercase()
        return "ACT-${cleanHmac.substring(0, 4)}-${cleanHmac.substring(4, 8)}-${cleanHmac.substring(8, 12)}"
    }

    /**
     * Verifies if a given license key is valid for this device code.
     */
    fun verifyLicenseKey(deviceCode: String, key: String): Boolean {
        val cleanKey = key.trim().uppercase()
        if (cleanKey == MASTER_OVERRIDE_KEY) return true
        val expected = generateLicenseKey(deviceCode)
        return cleanKey == expected
    }

    /**
     * Checks if this device is permanently activated.
     */
    fun isActivated(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val storedKey = prefs.getString(PREF_KEY, null) ?: return false
        val deviceCode = getDeviceCode(context)
        return verifyLicenseKey(deviceCode, storedKey)
    }

    /**
     * Attempts to activate the device with the provided key.
     * Returns true if successful and saved.
     */
    fun activate(context: Context, key: String): Boolean {
        val deviceCode = getDeviceCode(context)
        if (verifyLicenseKey(deviceCode, key)) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(PREF_KEY, key.trim().uppercase()).apply()
            return true
        }
        return false
    }

    private const val PREF_TRIAL_USED = "trial_used_flag"

    /**
     * Checks if the 1-chapter trial has already been used on this device.
     */
    fun isTrialUsed(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(PREF_TRIAL_USED, false)
    }

    /**
     * Marks the trial as consumed after the 1st chapter completes.
     */
    fun setTrialUsed(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(PREF_TRIAL_USED, true).apply()
    }

    private fun sha256(input: String): String {
        val md = MessageDigest.getInstance("SHA-256")
        val bytes = md.digest(input.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }

    private fun hmacSha256(input: String, secret: String): String {
        val keySpec = SecretKeySpec(secret.toByteArray(Charsets.UTF_8), "HmacSHA256")
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(keySpec)
        val bytes = mac.doFinal(input.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }
}
