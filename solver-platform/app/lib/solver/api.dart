import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'pace.dart';

class Resp {
  final int code;
  final String body;

  const Resp(this.code, this.body);

  @override
  String toString() => 'Resp($code, ${body.length > 100 ? "${body.substring(0, 100)}..." : body})';
}

const String kUserAgent =
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36';

class SolverStop implements Exception {
  final String message;
  const SolverStop(this.message);

  @override
  String toString() => 'SolverStop: $message';
}

/// Api wrapper around Dio for platform calls with pacing & rate limit guard
class SolverApi {
  final Map<String, String> baseHeaders;
  final CookieJar cookieJar;
  final Pace? pace;
  late final Dio dio;

  SolverApi({
    required this.baseHeaders,
    CookieJar? jar,
    this.pace,
  }) : cookieJar = jar ?? CookieJar() {
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (_) => true, // Accept all status codes
      ),
    );
    dio.interceptors.add(CookieManager(cookieJar));
  }

  /// Manually add cookie (strips leading dot if present)
  Future<void> addCookie(String domain, String name, String value) async {
    final d = domain.startsWith('.') ? domain.substring(1) : domain;
    final uri = Uri.parse('https://$d/');
    final cookie = Cookie(name, value)
      ..domain = d
      ..path = '/';
    await cookieJar.saveFromResponse(uri, [cookie]);
  }

  static bool _isRedirect(int code) =>
      code == 301 || code == 302 || code == 303 || code == 307 || code == 308;

  Future<Resp> req(
    String method,
    String url, {
    String? body,
    Map<String, String> extra = const {},
  }) async {
    int attempt = 0;
    const int maxRateRetries = 2;
    const int maxRedirects = 10;
    int redirects = 0;
    var currentMethod = method;
    var currentUrl = url;
    var currentBody = body ?? (method != 'GET' ? '{}' : null);
    Resp resp = const Resp(0, '');

    while (true) {
      final headers = Map<String, dynamic>.from(baseHeaders)..addAll(extra);

      // Redirects are followed manually: QUREO's TP bootstrap hands out its
      // session cookies on intermediate 307 responses. Dio's built-in
      // auto-redirect hides those hops from CookieManager, so the cookies are
      // never stored and the flow ends in a "Redirect loop detected" error.
      final options = Options(
        method: currentMethod,
        headers: headers,
        responseType: ResponseType.plain,
        followRedirects: false,
      );

      final response = await dio.request<String>(
        currentUrl,
        data: currentBody,
        options: options,
      );

      resp = Resp(response.statusCode ?? 0, response.data ?? '');

      if (_isRedirect(resp.code)) {
        final location = response.headers.value('location');
        if (location != null && location.isNotEmpty && redirects < maxRedirects) {
          redirects++;
          currentUrl = Uri.parse(currentUrl).resolve(location).toString();
          // 301/302/303 turn POST into GET (same as curl -L / OkHttp).
          if (resp.code == 301 || resp.code == 302 || resp.code == 303) {
            currentMethod = 'GET';
            currentBody = null;
          }
          continue;
        }
      }

      if (pace != null && resp.code == 429 && attempt < maxRateRetries) {
        await pace!.onRateLimit(attempt);
        attempt++;
        continue;
      }

      if (pace != null && resp.code == 403) {
        await pace!.onForbidden(currentUrl);
      }

      break;
    }

    return resp;
  }
}

bool isJson(String s) {
  try {
    jsonDecode(s);
    return true;
  } catch (_) {
    return false;
  }
}

bool isSuccessJson(Resp resp) =>
    resp.code >= 200 && resp.code <= 299 && isJson(resp.body);

Map<String, dynamic> requireJsonObject(Resp resp, String context) {
  if (resp.code < 200 || resp.code > 299) {
    final snippet = resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body;
    throw SolverStop('$context: HTTP ${resp.code} $snippet');
  }
  try {
    return jsonDecode(resp.body) as Map<String, dynamic>;
  } catch (_) {
    final snippet = resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body;
    throw SolverStop('$context: non-JSON $snippet');
  }
}

List<dynamic> requireJsonArray(Resp resp, String context) {
  if (resp.code < 200 || resp.code > 299) {
    final snippet = resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body;
    throw SolverStop('$context: HTTP ${resp.code} $snippet');
  }
  try {
    return jsonDecode(resp.body) as List<dynamic>;
  } catch (_) {
    final snippet = resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body;
    throw SolverStop('$context: non-JSON-array $snippet');
  }
}
