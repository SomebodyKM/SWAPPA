import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/models/user.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  );
});

enum AuthStatus { unknown, authenticated, unauthenticated }

@immutable
class AuthState {
  const AuthState({required this.status, this.user});
  final AuthStatus status;
  final User? user;

  const AuthState.unknown() : status = AuthStatus.unknown, user = null;
  const AuthState.unauthenticated()
    : status = AuthStatus.unauthenticated,
      user = null;
  const AuthState.authenticated(this.user) : status = AuthStatus.authenticated;
}

/// Owns the session. On construction it restores a stored session (token → /users/me).
class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    // Flip to unauthenticated if the API client's refresh fails.
    ref.read(apiClientProvider).onUnauthorized = () {
      state = const AuthState.unauthenticated();
    };
    _restore();
    return const AuthState.unknown();
  }

  Future<void> _restore() async {
    try {
      final user = await _repo.me();
      state = user != null
          ? AuthState.authenticated(user)
          : const AuthState.unauthenticated();
    } catch (_) {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> login({
    required String emailOrPhone,
    required String password,
  }) async {
    final user = await _repo.login(
      emailOrPhone: emailOrPhone,
      password: password,
    );
    state = AuthState.authenticated(user);
  }

  /// Register only — does not sign in (email verification required next).
  Future<String> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _repo.register(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    final user = await _repo.verifyEmail(email: email, code: code);
    state = AuthState.authenticated(user);
  }

  Future<void> resendCode(String email) => _repo.resendCode(email);

  Future<void> logout() async {
    await _repo.logout();
    ref.read(socketClientProvider).dispose();
    state = const AuthState.unauthenticated();
  }

  Future<void> deleteAccount() async {
    await _repo.deleteAccount();
    ref.read(socketClientProvider).dispose();
    state = const AuthState.unauthenticated();
  }

  /// Refresh the cached user (e.g. after profile/credit changes).
  Future<void> refreshUser() async {
    final user = await _repo.me();
    if (user != null) state = AuthState.authenticated(user);
  }

  /// Marks the post-signup profile+skills setup as done, both on the server
  /// and in local state, so the auth gate stops routing to onboarding.
  Future<void> completeOnboarding() async {
    await _repo.setOnboardingComplete();
    await refreshUser();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
