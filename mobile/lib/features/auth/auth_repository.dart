import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/token_store.dart';
import '../../shared/models/user.dart';

/// Talks to the backend `/auth/*` and `/users/me` endpoints.
class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  /// Register an unverified account. Returns the email that a code was sent to.
  /// (Backend returns no tokens until the email is verified.)
  Future<String> register({
    required String email,
    required String password,
    required String displayName,
    String? phone,
  }) async {
    final res = await _call(
      () => _api.dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'displayName': displayName,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      ),
    );
    return (res['email'] ?? email) as String;
  }

  /// Confirm the email code → stores tokens, returns the user.
  Future<User> verifyEmail({
    required String email,
    required String code,
  }) async {
    final data = await _call(
      () => _api.dio.post(
        '/auth/verify-email',
        data: {'email': email, 'code': code},
      ),
    );
    return _storeAndParse(data);
  }

  Future<void> resendCode(String email) async {
    await _call(
      () => _api.dio.post('/auth/resend-code', data: {'email': email}),
    );
  }

  Future<User> login({
    required String emailOrPhone,
    required String password,
  }) async {
    final data = await _call(
      () => _api.dio.post(
        '/auth/login',
        data: {'emailOrPhone': emailOrPhone, 'password': password},
      ),
    );
    return _storeAndParse(data);
  }

  /// Current signed-in user, or null if not authenticated.
  Future<User?> me() async {
    final token = await _tokens.accessToken;
    if (token == null) return null;
    final res = await _api.dio.get('/users/me');
    if (res.statusCode == 200 && res.data is Map) {
      return User.fromJson(res.data as Map<String, dynamic>);
    }
    return null;
  }

  Future<void> setOnboardingComplete() async {
    await _call(
      () => _api.dio.patch('/users/me', data: {'onboardingComplete': true}),
    );
  }

  /// Permanently delete the account and all related data, then clear tokens.
  Future<void> deleteAccount() async {
    try {
      await _api.dio.delete('/users/me'); // 204, no body to parse
    } on DioException catch (e) {
      if (e.response != null) throw ApiException.fromResponse(e.response!);
      throw ApiException(
        0,
        'NETWORK',
        'Network error — check your connection.',
      );
    }
    await _tokens.clear();
  }

  Future<void> logout() async {
    final refresh = await _tokens.refreshToken;
    try {
      await _api.dio.post('/auth/logout', data: {'refreshToken': refresh});
    } catch (_) {
      /* best effort */
    }
    await _tokens.clear();
  }

  Future<User> _storeAndParse(Map<String, dynamic> data) async {
    await _tokens.save(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
    );
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Runs a dio call, converting non-2xx / network failures into [ApiException].
  Future<Map<String, dynamic>> _call(Future<Response> Function() req) async {
    try {
      final res = await req();
      ensureOk(res);
      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      if (e.response != null) throw ApiException.fromResponse(e.response!);
      throw ApiException(
        0,
        'NETWORK',
        'Network error. Please try again later.',
      );
    }
  }
}
