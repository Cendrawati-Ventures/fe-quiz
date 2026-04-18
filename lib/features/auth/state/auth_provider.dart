import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/storage/secure_storage.dart';
import '../model/auth_user.dart';
import '../model/login_request.dart';
import '../service/auth_service.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.token,
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final String? token;
  final AuthUser? user;
  final bool isLoading;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    String? token,
    AuthUser? user,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get isAdmin => user?.role == UserRole.admin;
  bool get isSiswa => user?.role == UserRole.siswa;
}

final authServiceProvider = Provider<AuthService>((ref) {
  final dio = ref.watch(apiClientProvider);
  return AuthService(dio);
});

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _service;
  late final AppSecureStorage _secureStorage;

  @override
  AuthState build() {
    _service = ref.read(authServiceProvider);
    _secureStorage = ref.read(secureStorageProvider);
    Future<void>(() async {
      await _restoreSession();
    });
    return const AuthState(status: AuthStatus.checking);
  }

  Future<void> _restoreSession() async {
    final token = await _secureStorage.getToken();
    if (token != null && token.isNotEmpty) {
      final cachedUser = await _secureStorage.getUser();
      if (cachedUser != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          token: token,
          user: cachedUser,
        );
        _syncProfileInBackground();
        return;
      }

      try {
        final me = await _service.me();
        await _secureStorage.saveUser(me);
        state =
            AuthState(status: AuthStatus.authenticated, token: token, user: me);
        return;
      } on ApiError {
        await _secureStorage.clearAuthSession();
      }
    }

    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _syncProfileInBackground() async {
    try {
      final me = await _service.me();
      await _secureStorage.saveUser(me);
      state = state.copyWith(user: me);
    } catch (_) {
      // Keep current cached profile when refresh fails.
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final session = await _service.login(
        LoginRequest(username: username, password: password),
      );
      await _secureStorage.saveToken(session.token);
      await _secureStorage.saveUser(session.user);
      state = AuthState(
        status: AuthStatus.authenticated,
        token: session.token,
        user: session.user,
        isLoading: false,
      );
    } on ApiError catch (error) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        errorMessage: error.message,
      );
    } catch (_) {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        errorMessage: 'Login belum berhasil. Coba lagi.',
      );
    }
  }

  Future<void> logout() async {
    await _secureStorage.clearAuthSession();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
