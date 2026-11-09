import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;

import '../../app/config/app_config.dart';
import '../constants/app_constants.dart';
import 'network_exceptions.dart';
import 'session_store.dart';

/// A response kept whole, for endpoints where the status code or the redirect
/// target carries the answer (NextAuth replies to a credentials POST with a
/// 302 and puts the reason in the Location it would have used).
class HttpResponse {
  const HttpResponse({
    required this.statusCode,
    required this.body,
    required this.setCookies,
  });

  final int statusCode;
  final String body;

  /// One entry per cookie, taken from the split Set-Cookie headers.
  final List<String> setCookies;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  Map<String, dynamic>? get json {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Whatever the backend said, whichever key it used. Falling back to a
  /// generic status line only when it said nothing.
  String get message {
    final data = json;
    final reported = data?['error'] ?? data?['message'];
    if (reported is String && reported.trim().isNotEmpty) {
      return reported.trim();
    }
    return switch (statusCode) {
      400 => 'The request was rejected.',
      401 => 'Not authorised.',
      403 => 'Access denied.',
      404 => 'Not found.',
      429 => 'Too many attempts. Please try again later.',
      >= 500 => 'The server had a problem. Please try again.',
      _ => 'Unexpected response ($statusCode).',
    };
  }
}

/// Cookie-aware transport for the WorkingTrust backend.
class ApiClient {
  ApiClient._internal();

  factory ApiClient() => _instance;

  static const String _jsonType = 'application/json';
  static const String _formType = 'application/x-www-form-urlencoded';
  static const Duration _timeout = Duration(
    seconds: AppConstants.apiTimeoutSeconds,
  );

  static final ApiClient _instance = ApiClient._internal();

  http.Client? _client;

  String get baseUrl => AppConfig.backendUrl;

  /// Tests inject an [http.MockClient] so no socket is ever opened.
  void useClient(http.Client client) {
    _client?.close();
    _client = client;
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) => _json('GET', endpoint, queryParameters: queryParameters);

  Future<dynamic> post(
    String endpoint, {
    Object? body,
    Map<String, String>? queryParameters,
  }) => _json('POST', endpoint, body: body, queryParameters: queryParameters);

  Future<dynamic> put(String endpoint, {Object? body}) =>
      _json('PUT', endpoint, body: body);

  Future<dynamic> patch(String endpoint, {Object? body}) =>
      _json('PATCH', endpoint, body: body);

  /// Two account settings routes (`security/oauth`, `withdrawals`) read a JSON
  /// body on DELETE, so the body is optional rather than never sent.
  Future<dynamic> delete(String endpoint, {Object? body}) =>
      _json('DELETE', endpoint, body: body);

  /// JSON request/response helper. Throws [NetworkException] carrying the
  /// backend's own wording for any non-2xx answer.
  Future<dynamic> _json(
    String method,
    String endpoint, {
    Object? body,
    Map<String, String>? queryParameters,
  }) async {
    final response = await send(
      method,
      endpoint,
      body: body,
      queryParameters: queryParameters,
    );
    if (!response.isSuccess) {
      throw NetworkException(response.message, statusCode: response.statusCode);
    }
    return response.json ?? (response.body.isEmpty ? null : response.body);
  }

  /// Performs one request of any method. Redirects are never followed: a
  /// NextAuth 302 is the answer itself, and following it would drop the session
  /// cookie attached to that hop.
  Future<HttpResponse> send(
    String method,
    String endpoint, {
    Object? body,
    bool formEncoded = false,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint')
        .replace(queryParameters: queryParameters);
    final request = http.Request(method, uri)..followRedirects = false;
    request.headers['Accept'] = _jsonType;

    if (body != null) {
      if (formEncoded) {
        request.headers['Content-Type'] = _formType;
        request.bodyFields = (body as Map).cast<String, String>();
      } else {
        request.headers['Content-Type'] = _jsonType;
        request.body = jsonEncode(body);
      }
    }

    if (headers != null) request.headers.addAll(headers);

    return _perform(request);
  }

  /// Uploads [bytes] as one `multipart/form-data` part named [field].
  ///
  /// The avatar route reads `formData().get("file")` and rejects anything whose
  /// part Content-Type is not JPG, PNG or WEBP, so the MIME type is set by the
  /// caller rather than guessed from the file name.
  Future<HttpResponse> postFile(
    String endpoint, {
    required String field,
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) {
    final boundary = 'workingtrust${DateTime.now().microsecondsSinceEpoch}';
    final request = http.Request('POST', Uri.parse('$baseUrl$endpoint'))
      ..followRedirects = false;
    request.headers['Accept'] = _jsonType;
    request.headers['Content-Type'] = 'multipart/form-data; boundary=$boundary';
    request.bodyBytes = <int>[
      ...utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="$field"; filename="$filename"\r\n'
        'Content-Type: $mimeType\r\n\r\n',
      ),
      ...bytes,
      ...utf8.encode('\r\n--$boundary--\r\n'),
    ];
    return _perform(request);
  }

  /// Attaches the stored cookies, runs one request and absorbs the cookies the
  /// response sets. Every request answers through here, so the console shows
  /// exactly one line per round trip.
  Future<HttpResponse> _perform(http.Request request) async {
    final cookie = SessionStore.instance.cookieHeader;
    if (cookie != null) request.headers['Cookie'] = cookie;

    final client = _client ??= _defaultClient();
    final stopwatch = Stopwatch()..start();
    _log('--> ${request.method} ${request.url}');
    try {
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(_timeout);
      final setCookies =
          response.headersSplitValues['set-cookie'] ?? const <String>[];
      SessionStore.instance.absorb(setCookies);
      final result = HttpResponse(
        statusCode: response.statusCode,
        body: response.body,
        setCookies: setCookies,
      );
      _log(
        '<-- ${result.statusCode} ${request.method} ${request.url} '
        'in ${stopwatch.elapsedMilliseconds}ms'
        '${result.isSuccess ? '' : ' | ${result.message}'}',
      );
      return result;
    } on TimeoutException {
      _log(
        '<-- TIMEOUT ${request.method} ${request.url} after ${stopwatch.elapsedMilliseconds}ms',
      );
      throw NetworkException(
        'The server took too long to respond. Check your connection and try again.',
      );
    } on io.SocketException {
      _log(
        '<-- UNREACHABLE ${request.method} ${request.url} '
        '(no backend answering on $baseUrl)',
      );
      throw NetworkException(
        'Could not reach the server. Check that the backend is running and reachable from this device.',
      );
    } on http.ClientException catch (e) {
      _log('<-- CLIENT ERROR ${request.method} ${request.url}: ${e.message}');
      throw NetworkException(e.message);
    } on io.HttpException catch (e) {
      _log('<-- HTTP ERROR ${request.method} ${request.url}: $e');
      throw NetworkException('The connection to the server failed.');
    } catch (e) {
      if (e is NetworkException) rethrow;
      _log(
        '<-- FAILED ${request.method} ${request.url} in ${stopwatch.elapsedMilliseconds}ms: $e',
      );
      throw NetworkException('Something went wrong: $e');
    }
  }

  /// One line per request in the debug console, so a device run shows exactly
  /// which endpoint was hit. Request bodies are never logged — they carry
  /// passwords.
  void _log(String line) {
    if (AppConfig.enableLogging) debugPrint('[API] $line');
  }

  http.Client _defaultClient() {
    final raw = io.HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    return http_io.IOClient(raw);
  }
}
