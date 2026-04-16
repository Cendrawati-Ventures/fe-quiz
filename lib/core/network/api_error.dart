import 'package:dio/dio.dart';

class ApiError implements Exception {
  ApiError({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiError.fromDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;

    if (responseData is Map<String, dynamic>) {
      final dynamic apiMessage = responseData['message'];
      if (apiMessage is String && apiMessage.isNotEmpty) {
        return ApiError(message: apiMessage, statusCode: statusCode);
      }
    }

    return ApiError(
      message: error.message ?? 'Unknown API error',
      statusCode: statusCode,
    );
  }

  @override
  String toString() => 'ApiError(statusCode: $statusCode, message: $message)';
}
