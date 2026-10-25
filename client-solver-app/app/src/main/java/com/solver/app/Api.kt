package com.solver.app

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.ConnectionPool
import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.HttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

data class Resp(val code: Int, val body: String)

const val UA =
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36"

/** Shared cookie jar (login cookies must travel portal -> TP on QUREO). */
class CookieStore : CookieJar {
    private val all = mutableListOf<Cookie>()

    @Synchronized
    override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) {
        for (c in cookies) {
            all.removeAll { it.name == c.name && it.domain == c.domain && it.path == c.path }
            all.add(c)
        }
    }

    @Synchronized
    override fun loadForRequest(url: HttpUrl): List<Cookie> = all.filter { it.matches(url) }

    @Synchronized
    fun addCookie(domain: String, name: String, value: String) {
        // OkHttp rejects leading-dot domains ("unexpected domain"), strip it:
        // Builder.domain("qureo.education") still matches all subdomains.
        val d = domain.trimStart('.')
        val c = Cookie.Builder().name(name).value(value).domain(d).path("/").build()
        all.removeAll { it.name == c.name && it.domain == c.domain }
        all.add(c)
    }
}

class Api(
    private val baseHeaders: Map<String, String>,
    store: CookieStore = CookieStore(),
    private val pace: Pace? = null,
) {
    private val client: OkHttpClient = OkHttpClient.Builder()
        .cookieJar(store)
        .connectionPool(POOL)
        .build()
    private val jsonMedia = "application/json; charset=utf-8".toMediaType()

    suspend fun req(
        method: String,
        url: String,
        body: String? = null,
        extra: Map<String, String> = emptyMap(),
    ): Resp = withContext(Dispatchers.IO) {
        var attempt = 0
        var resp = Resp(0, "")
        while (true) {
            val b = Request.Builder().url(url)
            (baseHeaders + extra).forEach { (k, v) -> b.header(k, v) }
            when (method) {
                "GET" -> b.get()
                "POST" -> b.post((body ?: "{}").toRequestBody(jsonMedia))
                "PUT" -> b.put((body ?: "{}").toRequestBody(jsonMedia))
                else -> error("bad method $method")
            }
            resp = client.newCall(b.build()).execute().use { r ->
                Resp(r.code, r.body?.string() ?: "")
            }
            // Rate-limit guard: adaptive cooldown (Pace) then retry the request.
            if (pace != null && (resp.code == 429 || resp.code == 403) && attempt < MAX_RATE_RETRIES) {
                pace.onRateLimit(resp.code, attempt)
                attempt++
                continue
            }
            break
        }
        resp
    }

    companion object {
        private const val MAX_RATE_RETRIES = 2
        // Shared across all session clients: keeps TCP/TLS connections warm.
        private val POOL = ConnectionPool(50, 5, TimeUnit.MINUTES)
    }
}

fun isJson(s: String): Boolean = try {
    JSONObject(s); true
} catch (_: Exception) {
    try { JSONArray(s); true } catch (_: Exception) { false }
}

class SolverStop(msg: String) : Exception(msg)
