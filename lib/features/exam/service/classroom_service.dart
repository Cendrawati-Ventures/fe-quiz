import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../model/classroom_models.dart';

final classroomServiceProvider = Provider<ClassroomService>((ref) {
  final dio = ref.watch(apiClientProvider);
  return ClassroomService(dio);
});

final classListProvider = FutureProvider<List<AdminClassSummary>>((ref) async {
  final service = ref.watch(classroomServiceProvider);
  return service.listClasses();
});

final classDetailProvider =
    FutureProvider.family<AdminClassDetail, String>((ref, classId) async {
  final service = ref.watch(classroomServiceProvider);
  return service.getClassDetail(classId);
});

final myClassOptionsProvider =
    FutureProvider<List<StudentClassOption>>((ref) async {
  final service = ref.watch(classroomServiceProvider);
  return service.listMyClasses();
});

class ClassroomService {
  ClassroomService(this._dio);

  final Dio _dio;

  Future<List<AdminClassSummary>> listClasses() async {
    try {
      final response = await _dio.get<dynamic>('/classes');
      final data = response.data;
      if (data is List<dynamic>) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(AdminClassSummary.fromJson)
            .toList();
      }
      throw ApiError(message: 'Daftar kelas tidak valid.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<List<StudentClassOption>> listMyClasses() async {
    try {
      final response = await _dio.get<dynamic>('/classes/me');
      final data = response.data;
      if (data is List<dynamic>) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(StudentClassOption.fromJson)
            .where((item) => item.id.trim().isNotEmpty)
            .toList();
      }
      throw ApiError(message: 'Daftar kelas siswa tidak valid.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<AdminClassSummary> createClass({required String name}) async {
    try {
      final response = await _dio.post<dynamic>(
        '/classes',
        data: <String, dynamic>{'name': name},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AdminClassSummary.fromJson(data);
      }
      throw ApiError(message: 'Kelas gagal dibuat.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<AdminClassSummary> updateClass({
    required String classId,
    required String name,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        '/classes/$classId',
        data: <String, dynamic>{'name': name},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AdminClassSummary.fromJson(data);
      }
      throw ApiError(message: 'Kelas gagal diperbarui.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<void> deleteClass(String classId) async {
    try {
      await _dio.delete<void>('/classes/$classId');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<AdminClassDetail> getClassDetail(String classId) async {
    try {
      final response = await _dio.get<dynamic>('/classes/$classId');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AdminClassDetail.fromJson(data);
      }
      throw ApiError(message: 'Detail kelas tidak valid.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<AdminClassDetail> replaceClassStudents({
    required String classId,
    required List<String> studentIds,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        '/classes/$classId/students',
        data: <String, dynamic>{'studentIds': studentIds},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AdminClassDetail.fromJson(data);
      }
      throw ApiError(message: 'Data siswa kelas gagal diperbarui.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<AdminClassDetail> replaceClassSubjects({
    required String classId,
    required List<String> subjectIds,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        '/classes/$classId/subjects',
        data: <String, dynamic>{'subjectIds': subjectIds},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AdminClassDetail.fromJson(data);
      }
      throw ApiError(message: 'Akses ujian kelas gagal diperbarui.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }
}
