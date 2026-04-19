import 'dart:async';

import '../../../core/auth/auth_event_bus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/storage/secure_storage.dart';
import '../../exam/state/exam_state.dart';
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
  StreamSubscription<AuthEvent>? _authEventSubscription;

  @override
  AuthState build() {
    _service = ref.read(authServiceProvider);
    _secureStorage = ref.read(secureStorageProvider);
    final eventBus = ref.read(authEventBusProvider);

    _authEventSubscription?.cancel();
    _authEventSubscription = eventBus.stream.listen((event) {
      if (event != AuthEvent.unauthorized) {
        return;
      }
      ref.invalidate(examListProvider);
      ref.invalidate(subjectListProvider);
      ref.invalidate(myResultsProvider);
      ref.invalidate(adminResultsProvider);
      state = const AuthState(status: AuthStatus.unauthenticated);
      Future<void>(() async {
        await ref.read(examSessionProvider.notifier).clearSession();
      });
    });

    ref.onDispose(() {
      _authEventSubscription?.cancel();
      _authEventSubscription = null;
    });

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
      ref.invalidate(examListProvider);
      ref.invalidate(subjectListProvider);
      ref.invalidate(myResultsProvider);
      ref.invalidate(adminResultsProvider);
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

  Future<String?> updateDisplayName(String displayName) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      return 'Nama tampilan wajib diisi.';
    }
    return _updateProfile(
      displayName: trimmed,
      fallbackErrorMessage: 'Nama profil belum berhasil diperbarui.',
    );
  }

  Future<String?> updateStudentIdentity({
    required String fullName,
    required String rollNumber,
  }) async {
    final trimmedFullName = fullName.trim();
    final trimmedRollNumber = rollNumber.trim();
    if (trimmedFullName.isEmpty) {
      return 'Nama wajib diisi.';
    }
    if (trimmedRollNumber.isEmpty) {
      return 'No absen wajib diisi.';
    }

    return _updateProfile(
      fullName: trimmedFullName,
      rollNumber: trimmedRollNumber,
      fallbackErrorMessage: 'Data siswa belum berhasil disimpan.',
    );
  }

  Future<String?> _updateProfile({
    String? displayName,
    String? fullName,
    String? rollNumber,
    required String fallbackErrorMessage,
  }) async {
    if (state.status != AuthStatus.authenticated || state.user == null) {
      return 'Sesi login tidak ditemukan. Silakan login ulang.';
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updatedUser = await _service.updateMeProfile(
        displayName: displayName,
        fullName: fullName,
        rollNumber: rollNumber,
      );
      await _secureStorage.saveUser(updatedUser);
      state = state.copyWith(
        user: updatedUser,
        isLoading: false,
        clearError: true,
      );
      return null;
    } on ApiError catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return error.message;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: fallbackErrorMessage,
      );
      return fallbackErrorMessage;
    }
  }

  Future<void> refreshProfile() async {
    if (state.status != AuthStatus.authenticated || state.user == null) {
      return;
    }

    try {
      final me = await _service.me();
      await _secureStorage.saveUser(me);
      state = state.copyWith(user: me, clearError: true);
    } catch (_) {
      // Keep current profile when refresh fails.
    }
  }

  Future<void> logout() async {
    await _secureStorage.clearAuthSession();
    ref.invalidate(examListProvider);
    ref.invalidate(subjectListProvider);
    ref.invalidate(myResultsProvider);
    ref.invalidate(adminResultsProvider);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
