import 'package:dio/dio.dart';

import 'env.dart';
import 'token_store.dart';

/// Thin Dio wrapper that:
///  - attaches the access token to every request,
///  - transparently refreshes it on a 401 and retries once,
///  - calls [onUnauthorized] when the session can no longer be recovered.
class ApiClient {
  ApiClient(this._tokens) {
    dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        // 4xx/5xx throw a DioException so the 401→refresh interceptor runs and
        // services can convert failures into ApiException.
        validateStatus: (s) => s != null && s < 400,
      ),
    );
    _refreshDio = Dio(BaseOptions(baseUrl: Env.apiBaseUrl));
    dio.interceptors.add(_authInterceptor());
  }

  late final Dio dio;
  late final Dio _refreshDio;
  final TokenStore _tokens;

  /// Set by the auth layer; invoked when refresh fails (forces logout).
  void Function()? onUnauthorized;

  InterceptorsWrapper _authInterceptor() => InterceptorsWrapper(
    onRequest: (options, handler) async {
      if (options.extra['skipAuth'] != true) {
        final token = await _tokens.accessToken;
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      final response = error.response;
      final isAuthRetry = error.requestOptions.extra['retried'] == true;
      if (response?.statusCode == 401 && !isAuthRetry) {
        final ok = await _tryRefresh();
        if (ok) {
          final retried = await _retry(error.requestOptions);
          return handler.resolve(retried);
        }
        onUnauthorized?.call();
      }
      handler.next(error);
    },
  );

  Future<bool> _tryRefresh() async {
    final refresh = await _tokens.refreshToken;
    if (refresh == null) return false;
    try {
      final res = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refresh},
      );
      if (res.statusCode == 200 && res.data is Map) {
        await _tokens.save(
          access: res.data['accessToken'] as String,
          refresh: res.data['refreshToken'] as String,
        );
        return true;
      }
    } catch (_) {
      /* fall through */
    }
    await _tokens.clear();
    return false;
  }

  Future<Response<dynamic>> _retry(RequestOptions options) async {
    final token = await _tokens.accessToken;
    return dio.fetch(
      options
        ..headers['Authorization'] = 'Bearer $token'
        ..extra['retried'] = true,
    );
  }

  // ── JSON helpers: return decoded data or throw ApiException ────────────────
  Future<dynamic> getJson(String path, {Map<String, dynamic>? query}) =>
      _guard(() => dio.get(path, queryParameters: query));
  Future<dynamic> postJson(String path, {Object? body}) =>
      _guard(() => dio.post(path, data: body));
  Future<dynamic> patchJson(String path, {Object? body}) =>
      _guard(() => dio.patch(path, data: body));
  Future<dynamic> deleteJson(String path, {Object? body}) =>
      _guard(() => dio.delete(path, data: body));

  Future<dynamic> _guard(Future<Response> Function() req) async {
    try {
      final res = await req();
      return res.data;
    } on DioException catch (e) {
      if (e.response != null) throw ApiException.fromResponse(e.response!);
      throw ApiException(
        0,
        'NETWORK',
        'Network error — check your connection.',
      );
    }
  }
}

/// Normalized error surfaced to the UI from a non-2xx response.
class ApiException implements Exception {
  ApiException(this.statusCode, this.code, this.message, [this.details]);

  final int statusCode;
  final String code;
  final String message;
  final dynamic details;

  factory ApiException.fromResponse(Response res) {
    final data = res.data;
    if (data is Map && data['error'] is Map) {
      final e = data['error'] as Map;
      return ApiException(
        res.statusCode ?? 0,
        (e['code'] ?? 'ERROR').toString(),
        (e['message'] ?? 'Something went wrong').toString(),
        e['details'],
      );
    }
    return ApiException(res.statusCode ?? 0, 'ERROR', 'Something went wrong');
  }

  bool get isPaymentRequired => statusCode == 402;
  bool get isLimitReached => code == 'LIMIT_REACHED';
  bool get isPremiumRequired => code == 'PREMIUM_REQUIRED';

  /// A single field this error is tagged to (e.g. `password`, `emailOrPhone`).
  String? get field =>
      (details is Map) ? (details as Map)['field'] as String? : null;

  /// Per-field validation messages (from the backend `VALIDATION` error).
  Map<String, String> get fieldErrors {
    if (details is Map && (details as Map)['fieldErrors'] is Map) {
      return ((details as Map)['fieldErrors'] as Map).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
    }
    return const {};
  }

  /// The message that belongs to [fieldName], from either [field] or [fieldErrors].
  String? messageForField(String fieldName) {
    if (fieldErrors.containsKey(fieldName)) return fieldErrors[fieldName];
    if (field == fieldName) return message;
    return null;
  }

  @override
  String toString() => message;
}

/// Throws [ApiException] for non-2xx responses; otherwise returns the response.
Response<T> ensureOk<T>(Response<T> res) {
  final code = res.statusCode ?? 0;
  if (code < 200 || code >= 300) throw ApiException.fromResponse(res);
  return res;
}
