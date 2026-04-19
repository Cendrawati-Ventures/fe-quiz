import 'package:dio/dio.dart';

import '../../../core/network/api_error.dart';
import '../model/auth_session.dart';
import '../model/auth_user.dart';
import '../model/login_request.dart';

class AuthService {
  AuthService(this._dio);

  final Dio _dio;
  static const Duration _authConnectTimeout = Duration(seconds: 8);
  static const Duration _authSendTimeout = Duration(seconds: 8);
  static const Duration _authReceiveTimeout = Duration(seconds: 12);

  Future<AuthSession> login(LoginRequest request) async {
    try {
      final response = await _dio.post<dynamic>(
        '/auth/login',
        data: request.toJson(),
        options: Options(
          extra: <String, dynamic>{'skipAuthToken': true},
          connectTimeout: _authConnectTimeout,
          sendTimeout: _authSendTimeout,
          receiveTimeout: _authReceiveTimeout,
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final token = data['token'];
        final user = data['user'];
        if (token is String &&
            token.isNotEmpty &&
            user is Map<String, dynamic>) {
          return AuthSession.fromJson(data);
        }
      }

      throw ApiError(message: 'Login belum berhasil. Coba lagi.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<AuthUser> me() async {
    try {
      final response = await _dio.get<dynamic>(
        '/users/me',
        options: Options(
          connectTimeout: _authConnectTimeout,
          sendTimeout: _authSendTimeout,
          receiveTimeout: _authReceiveTimeout,
        ),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AuthUser.fromJson(data);
      }
      throw ApiError(message: 'Profil akun belum bisa dimuat.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<AuthUser> updateMeProfile({
    String? displayName,
    String? fullName,
    String? className,
    String? rollNumber,
  }) async {
    final payload = <String, dynamic>{};
    if (displayName != null) {
      payload['displayName'] = displayName;
    }
    if (fullName != null) {
      payload['fullName'] = fullName;
    }
    if (className != null) {
      payload['className'] = className;
    }
    if (rollNumber != null) {
      payload['rollNumber'] = rollNumber;
    }

    if (payload.isEmpty) {
      throw ApiError(message: 'Tidak ada data profil yang dikirim.');
    }

    try {
      final response = await _dio.put<dynamic>(
        '/users/me',
        data: payload,
        options: Options(
          connectTimeout: _authConnectTimeout,
          sendTimeout: _authSendTimeout,
          receiveTimeout: _authReceiveTimeout,
        ),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AuthUser.fromJson(data);
      }
      throw ApiError(message: 'Profil belum bisa diperbarui.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }
}
