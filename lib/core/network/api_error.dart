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

    if (responseData is String && responseData.isNotEmpty) {
      return ApiError(message: responseData, statusCode: statusCode);
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiError(
          message:
              'Connection timeout. Android emulator uses 10.0.2.2:8091, while physical Android must use PC LAN IP via --dart-define=API_BASE_URL=http://<PC_IP>:8091.',
          statusCode: statusCode,
        );
      case DioExceptionType.connectionError:
        return ApiError(
          message:
              'Unable to connect to server. Emulator: use 10.0.2.2:8091. Physical Android: use PC LAN IP via --dart-define=API_BASE_URL=http://<PC_IP>:8091.',
          statusCode: statusCode,
        );
      case DioExceptionType.badCertificate:
        return ApiError(
          message: 'Secure connection failed.',
          statusCode: statusCode,
        );
      case DioExceptionType.cancel:
        return ApiError(
            message: 'Request was canceled.', statusCode: statusCode);
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    if (statusCode == 401) {
      return ApiError(
          message: 'Unauthorized. Please login again.', statusCode: 401);
    }
    if (statusCode == 404) {
      return ApiError(message: 'Endpoint not found.', statusCode: 404);
    }
    if (statusCode != null && statusCode >= 500) {
      return ApiError(
        message: 'Server error. Please try again later.',
        statusCode: statusCode,
      );
    }

    return ApiError(
      message: error.message ?? 'Unknown API error',
      statusCode: statusCode,
    );
  }

  @override
  String toString() => 'ApiError(statusCode: $statusCode, message: $message)';
}
