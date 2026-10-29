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
            // Rate-limit guard: 429 only. 403 = locked/forbidden, fail fast with context.
            if (pace != null && resp.code == 429 && attempt < MAX_RATE_RETRIES) {
                pace.onRateLimit(attempt)
                attempt++
                continue
            }
            if (pace != null && resp.code == 403) {
                pace.onForbidden(url)
            }
            // 403 = locked/forbidden (not rate limit). Don't retry, let caller handle.
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

/** True if response is 2xx AND body parses as JSON (object or array). */
fun isSuccessJson(resp: Resp): Boolean = resp.code in 200..299 && isJson(resp.body)

/** Parse JSON object only if 2xx, else throw SolverStop with context. */
@Throws(SolverStop::class)
fun requireJsonObject(resp: Resp, context: String): JSONObject {
    if (resp.code !in 200..299) throw SolverStop("$context: HTTP ${resp.code} ${resp.body.take(200)}")
    return try { JSONObject(resp.body) } catch (e: Exception) { throw SolverStop("$context: non-JSON ${resp.body.take(200)}") }
}

/** Parse JSON array only if 2xx, else throw SolverStop with context. */
@Throws(SolverStop::class)
fun requireJsonArray(resp: Resp, context: String): JSONArray {
    if (resp.code !in 200..299) throw SolverStop("$context: HTTP ${resp.code} ${resp.body.take(200)}")
    return try { JSONArray(resp.body) } catch (e: Exception) { throw SolverStop("$context: non-JSON-array ${resp.body.take(200)}") }
}

class SolverStop(msg: String) : Exception(msg)
