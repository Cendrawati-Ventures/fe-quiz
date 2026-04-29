import 'dart:async';

import '../../../app/student_route_history_state.dart';
import '../../../core/auth/auth_event_bus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/storage/secure_storage.dart';
import '../../exam/service/classroom_service.dart';
import '../../exam/state/exam_state.dart';
import '../../exam/state/student_class_scope_state.dart';
import '../../exam_monitoring/state/student_monitoring_state.dart';
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
  static const Duration _sessionValidationInterval = Duration(seconds: 10);

  late final AuthService _service;
  late final AppSecureStorage _secureStorage;
  late final ApiClient _apiClient;
  StreamSubscription<AuthEvent>? _authEventSubscription;
  Timer? _sessionValidationTimer;
  bool _isSessionValidationRunning = false;
  bool _isInvalidatingSession = false;

  @override
  AuthState build() {
    _service = ref.read(authServiceProvider);
    _secureStorage = ref.read(secureStorageProvider);
    _apiClient = ref.read(apiClientControllerProvider);
    final eventBus = ref.read(authEventBusProvider);

    _authEventSubscription?.cancel();
    _authEventSubscription = eventBus.stream.listen((event) {
      if (event != AuthEvent.unauthorized) {
        return;
      }
      unawaited(_invalidateSession());
    });
    _startSessionValidationTimer();

    ref.onDispose(() {
      _authEventSubscription?.cancel();
      _authEventSubscription = null;
      _sessionValidationTimer?.cancel();
      _sessionValidationTimer = null;
    });

    Future<void>(() async {
      await _restoreSession();
    });
    return const AuthState(status: AuthStatus.checking);
  }

  void _startSessionValidationTimer() {
    _sessionValidationTimer?.cancel();
    _sessionValidationTimer = Timer.periodic(_sessionValidationInterval, (_) {
      unawaited(_validateSessionInBackground());
    });
  }

  Future<void> _validateSessionInBackground() async {
    if (_isSessionValidationRunning ||
        state.status != AuthStatus.authenticated ||
        state.user == null) {
      return;
    }

    _isSessionValidationRunning = true;
    try {
      final me = await _service.me();
      await _secureStorage.saveUser(me);
      if (!_isSameUser(state.user, me)) {
        state = state.copyWith(user: me, clearError: true);
      }
    } on ApiError catch (error) {
      if (_shouldInvalidateSession(error)) {
        await _invalidateSession();
      }
    } catch (_) {
      // Keep current session when the background sync fails unexpectedly.
    } finally {
      _isSessionValidationRunning = false;
    }
  }

  bool _isSameUser(AuthUser? current, AuthUser next) {
    if (current == null) {
      return false;
    }
    return current.id == next.id &&
        current.username == next.username &&
        current.displayName == next.displayName &&
        current.fullName == next.fullName &&
        current.classId == next.classId &&
        current.className == next.className &&
        current.rollNumber == next.rollNumber &&
        current.role == next.role;
  }

  bool _shouldInvalidateSession(ApiError error) {
    final statusCode = error.statusCode;
    if (statusCode == 401 || statusCode == 403 || statusCode == 404) {
      return true;
    }

    final message = error.message.toLowerCase();
    return message.contains('token') ||
        message.contains('unauthorized') ||
        message.contains('akses') ||
        message.contains('sesi') ||
        message.contains('login ulang') ||
        message.contains('pengguna tidak ditemukan');
  }

  Future<void> _invalidateSession() async {
    if (_isInvalidatingSession) {
      return;
    }
    _isInvalidatingSession = true;

    try {
      await ref
          .read(studentMonitoringSessionProvider)
          .stop(markFinished: false);
      _apiClient.setAuthToken(null);
      await _secureStorage.clearAuthSession();
      await ref.read(studentSelectedClassIdProvider.notifier).clear();
      await ref.read(studentRouteHistoryProvider.notifier).clear();
      ref.invalidate(examListProvider);
      ref.invalidate(subjectListProvider);
      ref.invalidate(myResultsProvider);
      ref.invalidate(adminResultsProvider);
      ref.invalidate(myClassOptionsProvider);
      state = const AuthState(status: AuthStatus.unauthenticated);
      await ref.read(examSessionProvider.notifier).clearSession();
    } finally {
      _isInvalidatingSession = false;
    }
  }

  Future<void> _restoreSession() async {
    final token = await _secureStorage.getToken();
    if (token != null && token.isNotEmpty) {
      _apiClient.setAuthToken(token);
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
        _apiClient.setAuthToken(null);
      }
    }

    _apiClient.setAuthToken(null);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _syncProfileInBackground() async {
    try {
      final me = await _service.me();
      await _secureStorage.saveUser(me);
      if (!_isSameUser(state.user, me)) {
        state = state.copyWith(user: me);
      }
    } on ApiError catch (error) {
      if (_shouldInvalidateSession(error)) {
        await _invalidateSession();
      }
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
      _apiClient.setAuthToken(session.token);
      await _secureStorage.saveToken(session.token);
      await _secureStorage.saveUser(session.user);
      await ref.read(examSessionProvider.notifier).clearSession();
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

  Future<String?> deleteAccount() async {
    final currentUser = state.user;
    if (state.status != AuthStatus.authenticated || currentUser == null) {
      return 'Sesi login tidak ditemukan. Silakan login ulang.';
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.deleteMyAccount();
      await _invalidateSession();
      return null;
    } on ApiError catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return error.message;
    } catch (_) {
      const message = 'Akun belum berhasil dihapus. Coba lagi.';
      state = state.copyWith(isLoading: false, errorMessage: message);
      return message;
    }
  }

  Future<void> logout() async {
    await _invalidateSession();
  }
}
