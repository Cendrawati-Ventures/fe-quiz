import 'package:dio/dio.dart';

import '../../../core/network/api_error.dart';
import '../model/login_request.dart';

class AuthService {
  AuthService(this._dio);

  final Dio _dio;

  Future<String> login(LoginRequest request) async {
    try {
      final response = await _dio.post<dynamic>(
        '/auth/login',
        data: request.toJson(),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final token = data['token'];
        if (token is String && token.isNotEmpty) {
          return token;
        }
      }

      throw ApiError(message: 'Token not found in response');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }
}
