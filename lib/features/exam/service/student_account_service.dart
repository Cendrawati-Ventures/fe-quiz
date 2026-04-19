import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/network/api_client.dart";
import "../../../core/network/api_error.dart";
import "../model/student_account.dart";

final studentAccountServiceProvider = Provider<StudentAccountService>((ref) {
  final dio = ref.watch(apiClientProvider);
  return StudentAccountService(dio);
});

final studentAccountsProvider = FutureProvider<List<StudentAccount>>((
  ref,
) async {
  final service = ref.watch(studentAccountServiceProvider);
  return service.listStudents();
});

class StudentAccountService {
  StudentAccountService(this._dio);

  final Dio _dio;

  Future<List<StudentAccount>> listStudents() async {
    try {
      final response = await _dio.get<dynamic>("/students");
      final data = response.data;
      if (data is List<dynamic>) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(StudentAccount.fromJson)
            .toList();
      }
      throw ApiError(message: "Respons daftar siswa tidak valid.");
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<StudentAccount> createStudent({
    required String username,
    required String password,
    String? fullName,
    String? classId,
    String? rollNumber,
  }) async {
    final payload = <String, dynamic>{
      "username": username,
      "password": password,
    };
    if (fullName != null) {
      payload["fullName"] = fullName;
    }
    if (classId != null) {
      payload["classId"] = classId;
    }
    if (rollNumber != null) {
      payload["rollNumber"] = rollNumber;
    }

    try {
      final response = await _dio.post<dynamic>(
        "/students",
        data: payload,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return StudentAccount.fromJson(data);
      }
      throw ApiError(message: "Respons pembuatan akun siswa tidak valid.");
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<void> deleteStudent(String studentId) async {
    try {
      await _dio.delete<void>("/students/$studentId");
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }
}
