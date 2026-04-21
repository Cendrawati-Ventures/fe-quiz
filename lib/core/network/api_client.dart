import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../auth/auth_event_bus.dart';
import '../storage/secure_storage.dart';

final apiClientProvider = Provider<Dio>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final authEventBus = ref.watch(authEventBusProvider);
  return ApiClient(secureStorage, authEventBus: authEventBus).dio;
});

class ApiClient {
  ApiClient(
    this._secureStorage, {
    AuthEventBus? authEventBus,
    Dio? dio,
    Logger? logger,
  })  : _authEventBus = authEventBus,
        _dio = dio ?? Dio(_buildBaseOptions()),
        _logger = logger ?? Logger() {
    _setupInterceptors();
    if (kDebugMode) {
      _logger.i('URL dasar API: ${_dio.options.baseUrl}');
    }
  }

  static const String _localhostBaseUrl = 'http://localhost:8091';
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:8091';
  static const String _skipAuthTokenKey = 'skipAuthToken';

  final Dio _dio;
  final AppSecureStorage _secureStorage;
  final AuthEventBus? _authEventBus;
  final Logger _logger;
  bool _isHandlingUnauthorized = false;

  Dio get dio => _dio;

  static BaseOptions _buildBaseOptions() {
    return BaseOptions(
      baseUrl: _resolveBaseUrl(),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: <String, dynamic>{
        Headers.acceptHeader: 'application/json',
        Headers.contentTypeHeader: 'application/json',
      },
    );
  }

  static String _resolveBaseUrl() {
    const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _androidEmulatorBaseUrl;
    }
    return _localhostBaseUrl;
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!_shouldSkipAuth(options)) {
            final token = await _secureStorage.getToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          _logError(error);
          if (_shouldClearToken(error)) {
            await _clearAuthToken();
          }
          handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: false,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          compact: true,
          maxWidth: 120,
          filter: (options, _) {
            final path = _normalizePath(options.path);
            return path != '/auth/login';
          },
        ),
      );
    }
  }

  bool _shouldSkipAuth(RequestOptions options) {
    if (options.extra[_skipAuthTokenKey] == true) {
      return true;
    }
    final path = _normalizePath(options.path);
    return path == '/auth/login';
  }

  bool _shouldClearToken(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != 401 && statusCode != 403) {
      return false;
    }
    if (_shouldSkipAuth(error.requestOptions)) {
      return false;
    }
    if (statusCode == 401) {
      return true;
    }

    final data = error.response?.data;
    final serverMessage = data is Map<String, dynamic>
        ? data['message']?.toString().toLowerCase()
        : data?.toString().toLowerCase();
    if (serverMessage == null || serverMessage.isEmpty) {
      return false;
    }

    return serverMessage.contains('unauthorized') ||
        serverMessage.contains('token') ||
        serverMessage.contains('jwt') ||
        serverMessage.contains('invalid') ||
        serverMessage.contains('expired') ||
        serverMessage.contains('akses ditolak');
  }

  Future<void> _clearAuthToken() async {
    if (_isHandlingUnauthorized) {
      return;
    }
    _isHandlingUnauthorized = true;
    try {
      await _secureStorage.clearAuthSession();
      _authEventBus?.emitUnauthorized();
    } finally {
      _isHandlingUnauthorized = false;
    }
  }

  void _logError(DioException error) {
    final statusCode = error.response?.statusCode;
    final isClientError =
        statusCode != null && statusCode >= 400 && statusCode < 500;

    _logger.e(
      'Permintaan API gagal: ${error.requestOptions.method} ${error.requestOptions.uri}',
      error: isClientError ? error.message : (error.error ?? error.message),
      stackTrace: isClientError ? null : error.stackTrace,
    );
  }

  static String _normalizePath(String path) {
    final parsed = Uri.tryParse(path);
    if (parsed == null) {
      return path;
    }
    if (parsed.hasScheme) {
      return parsed.path;
    }
    return parsed.path.isEmpty ? path : parsed.path;
  }
}
