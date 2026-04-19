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
        return ApiError(
            message: 'Permintaan dibatalkan.', statusCode: statusCode);
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    return ApiError(
        message: _fallbackByStatus(statusCode), statusCode: statusCode);
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
      return 'Username atau kata sandi tidak sesuai.';
    }
    if (normalized.contains('subject name already exists')) {
      return 'Nama ujian sudah dipakai.';
    }
    if (normalized.contains('subject not found')) {
      return 'Ujian tidak ditemukan.';
    }
    if (normalized.contains('attempt limit reached')) {
      return 'Batas percobaan untuk ujian ini sudah habis.';
    }
    if (normalized.contains('maksimum 30 soal') ||
        normalized.contains('melebihi 30 soal')) {
      return 'Jumlah soal maksimal 30 untuk satu ujian.';
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
    if (normalized.contains('nama ujian sudah digunakan') ||
        normalized.contains('ujian tidak ditemukan') ||
        normalized.contains('nama mata pelajaran sudah digunakan') ||
        normalized.contains('mata pelajaran tidak ditemukan') ||
        normalized.contains('batas percobaan') ||
        normalized.contains('jumlah soal') ||
        normalized.contains('urutan soal') ||
        normalized.contains('jawaban') ||
        normalized.contains('kata sandi') ||
        normalized.contains('username')) {
      return message.trim();
    }
    if (normalized.contains('invalid token') ||
        normalized.contains('jwt') ||
        normalized.contains('token tidak valid')) {
      return 'Sesi kamu sudah berakhir. Silakan login lagi.';
    }
    if (normalized.contains('unauthorized') ||
        normalized.contains('akses ditolak')) {
      if (statusCode == 403) {
        return 'Kamu tidak punya izin untuk melakukan aksi ini.';
      }
      return 'Sesi kamu sudah berakhir. Silakan login lagi.';
    }
    if (normalized.contains('route not found') || normalized == 'not found') {
      return 'Data yang dicari tidak ditemukan.';
    }
    if (normalized.contains('internal server error')) {
      return 'Terjadi gangguan pada sistem. Coba lagi beberapa saat.';
    }

    if (statusCode != null && statusCode >= 500) {
      return _fallbackByStatus(statusCode);
    }
    return message.trim().isEmpty
        ? _fallbackByStatus(statusCode)
        : message.trim();
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
