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
        return ApiError(
          message: _friendlyFromServer(apiMessage, statusCode: statusCode),
          statusCode: statusCode,
        );
      }
    }

    if (responseData is String && responseData.isNotEmpty) {
      return ApiError(
        message: _friendlyFromServer(responseData, statusCode: statusCode),
        statusCode: statusCode,
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiError(
          message: 'Koneksi sedang lambat. Coba lagi sebentar.',
          statusCode: statusCode,
        );
      case DioExceptionType.connectionError:
        return ApiError(
          message: 'Tidak bisa terhubung ke server. Periksa koneksi kamu.',
          statusCode: statusCode,
        );
      case DioExceptionType.badCertificate:
        return ApiError(
          message: 'Koneksi aman sedang bermasalah. Coba lagi nanti.',
          statusCode: statusCode,
        );
      case DioExceptionType.cancel:
        return ApiError(message: 'Permintaan dibatalkan.', statusCode: statusCode);
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    return ApiError(message: _fallbackByStatus(statusCode), statusCode: statusCode);
  }

  static String _friendlyFromServer(
    String message, {
    required int? statusCode,
  }) {
    final normalized = message.trim().toLowerCase();
    if (normalized.isEmpty) {
      return _fallbackByStatus(statusCode);
    }

    if (normalized.contains('invalid username or password')) {
      return 'Username atau password tidak sesuai.';
    }
    if (normalized.contains('subject name already exists')) {
      return 'Nama subject sudah dipakai.';
    }
    if (normalized.contains('subject not found')) {
      return 'Subject tidak ditemukan.';
    }
    if (normalized.contains('attempt limit reached')) {
      return 'Batas percobaan untuk subject ini sudah habis.';
    }
    if (normalized.contains('maksimum 30 soal')) {
      return 'Jumlah pertanyaan maksimal 30 untuk satu subject.';
    }
    if (normalized.contains('total weight')) {
      return 'Total poin pertanyaan melebihi batas.';
    }
    if (normalized.contains('question not found')) {
      return 'Pertanyaan tidak ditemukan.';
    }
    if (normalized.contains('opsi soal')) {
      return 'Opsi jawaban belum sesuai.';
    }
    if (normalized.contains('jawaban benar')) {
      return 'Jawaban benar belum sesuai dengan opsi.';
    }
    if (normalized.contains('validation error')) {
      return 'Data yang dimasukkan belum sesuai.';
    }
    if (normalized.contains('unauthorized') ||
        normalized.contains('invalid token') ||
        normalized.contains('jwt')) {
      return 'Sesi kamu sudah berakhir. Silakan login lagi.';
    }
    if (normalized.contains('route not found') || normalized == 'not found') {
      return 'Data yang dicari tidak ditemukan.';
    }
    if (normalized.contains('internal server error')) {
      return 'Terjadi gangguan pada sistem. Coba lagi beberapa saat.';
    }

    return _fallbackByStatus(statusCode);
  }

  static String _fallbackByStatus(int? statusCode) {
    if (statusCode == 400 || statusCode == 422) {
      return 'Data yang dimasukkan belum sesuai.';
    }
    if (statusCode == 401 || statusCode == 403) {
      return 'Akses kamu tidak diizinkan. Silakan login lagi.';
    }
    if (statusCode == 404) {
      return 'Data yang dicari tidak ditemukan.';
    }
    if (statusCode == 409) {
      return 'Data sudah digunakan. Gunakan data lain.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Terjadi gangguan pada sistem. Coba lagi beberapa saat.';
    }
    return 'Permintaan belum berhasil diproses. Coba lagi.';
  }

  @override
  String toString() => 'ApiError(statusCode: $statusCode, message: $message)';
}
