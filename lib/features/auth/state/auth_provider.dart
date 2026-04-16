import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/storage/secure_storage.dart';
import '../model/login_request.dart';
import '../service/auth_service.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.token,
    this.isLoading = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final String? token;
  final bool isLoading;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    String? token,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
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
    _restoreSession();
    return const AuthState(status: AuthStatus.checking);
  }

  Future<void> _restoreSession() async {
    final token = await _secureStorage.getToken();
    if (token != null && token.isNotEmpty) {
      state = AuthState(status: AuthStatus.authenticated, token: token);
      return;
    }

    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final token = await _service.login(
        LoginRequest(identifier: identifier, password: password),
      );
      await _secureStorage.saveToken(token);
      state = AuthState(
        status: AuthStatus.authenticated,
        token: token,
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
        errorMessage: 'Login failed',
      );
    }
  }

  Future<void> logout() async {
    await _secureStorage.deleteToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
