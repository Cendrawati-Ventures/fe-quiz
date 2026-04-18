import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../storage/secure_storage.dart';

final apiClientProvider = Provider<Dio>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return ApiClient(secureStorage).dio;
});

class ApiClient {
  ApiClient(this._secureStorage, {Dio? dio, Logger? logger})
      : _dio = dio ?? Dio(_buildBaseOptions()),
        _logger = logger ?? Logger() {
    _setupInterceptors();
    if (kDebugMode) {
      _logger.i('API base URL: ${_dio.options.baseUrl}');
    }
  }

  static const String _localhostBaseUrl = 'http://localhost:8091';
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:8091';
  static const String _skipAuthTokenKey = 'skipAuthToken';

  final Dio _dio;
  final AppSecureStorage _secureStorage;
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
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          compact: true,
          maxWidth: 120,
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
    if (statusCode != 401) {
      return false;
    }
    return !_shouldSkipAuth(error.requestOptions);
  }

  Future<void> _clearAuthToken() async {
    if (_isHandlingUnauthorized) {
      return;
    }
    _isHandlingUnauthorized = true;
    try {
      await _secureStorage.clearAuthSession();
    } finally {
      _isHandlingUnauthorized = false;
    }
  }

  void _logError(DioException error) {
    _logger.e(
      'API request failed: ${error.requestOptions.method} ${error.requestOptions.uri}',
      error: error.error ?? error.message,
      stackTrace: error.stackTrace,
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
