import 'package:dio/dio.dart';

import '../../../core/network/api_error.dart';
import '../model/auth_session.dart';
import '../model/auth_user.dart';
import '../model/login_request.dart';

class AuthService {
  AuthService(this._dio);

  final Dio _dio;

  Future<AuthSession> login(LoginRequest request) async {
    try {
      final response = await _dio.post<dynamic>(
        '/auth/login',
        data: request.toJson(),
        options: Options(extra: <String, dynamic>{'skipAuthToken': true}),
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

      throw ApiError(message: 'Login response is invalid');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<AuthUser> me() async {
    try {
      final response = await _dio.get<dynamic>('/users/me');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AuthUser.fromJson(data);
      }
      throw ApiError(message: 'User profile response is invalid');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }
}
