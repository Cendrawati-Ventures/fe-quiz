import 'package:dio/dio.dart';

import '../../../core/network/api_error.dart';
import '../model/exam_models.dart';

class ExamService {
  ExamService(this._dio);

  final Dio _dio;

  Dio get client => _dio;

  Future<List<ApiExam>> listExams() async {
    try {
      final response = await _dio.get<dynamic>('/exams');
      final data = response.data;
      if (data is List<dynamic>) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(ApiExam.fromJson)
            .toList();
      }
      throw ApiError(message: 'Daftar ujian belum bisa dimuat.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<List<ApiSubject>> listSubjects() async {
    try {
      final response = await _dio.get<dynamic>('/api/subjects');
      final data = response.data;
      if (data is List<dynamic>) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(ApiSubject.fromJson)
            .toList();
      }
      throw ApiError(message: 'Daftar subject belum bisa dimuat.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<ApiSubject> createSubject({
    required String name,
    required String description,
    required int durationMinutes,
    required int attemptLimit,
    required bool allowReview,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/subjects',
        data: <String, dynamic>{
          'name': name,
          'description': description,
          'durationMinutes': durationMinutes,
          'attemptLimit': attemptLimit,
          'allowReview': allowReview,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ApiSubject.fromJson(data);
      }
      throw ApiError(message: 'Subject belum berhasil disimpan.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<ApiSubject> updateSubject({
    required String id,
    required String name,
    required String description,
    required int durationMinutes,
    required int attemptLimit,
    required bool allowReview,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        '/api/subjects/$id',
        data: <String, dynamic>{
          'name': name,
          'description': description,
          'durationMinutes': durationMinutes,
          'attemptLimit': attemptLimit,
          'allowReview': allowReview,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ApiSubject.fromJson(data);
      }
      throw ApiError(message: 'Perubahan subject belum berhasil disimpan.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<void> deleteSubject(String id) async {
    try {
      await _dio.delete<dynamic>('/api/subjects/$id');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<StartAttemptResponse> startAttempt({
    required String examId,
    required String subjectId,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/attempts/start',
        data: <String, dynamic>{'examId': examId, 'subjectId': subjectId},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return StartAttemptResponse.fromJson(data);
      }
      throw ApiError(message: 'Ujian belum bisa dimulai.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<AttemptDetail> getAttemptById(String attemptId) async {
    try {
      final response = await _dio.get<dynamic>('/attempts/$attemptId');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AttemptDetail.fromJson(data);
      }
      throw ApiError(message: 'Detail ujian belum bisa dimuat.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<SaveAnswerResponse> saveAnswer({
    required String attemptId,
    required String questionId,
    required Object? answer,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/answers',
        data: <String, dynamic>{
          'attemptId': attemptId,
          'questionId': questionId,
          'answer': answer,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return SaveAnswerResponse.fromJson(data);
      }
      throw ApiError(message: 'Jawaban belum berhasil disimpan.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<ProctoringResponse> sendProctoringEvents(
    List<ProctoringEventPayload> events,
  ) async {
    if (events.isEmpty) {
      return const ProctoringResponse(accepted: 0, ignored: 0);
    }

    try {
      final response = await _dio.post<dynamic>(
        '/proctoring/events',
        data: <String, dynamic>{
          'events': events.map((event) => event.toJson()).toList(),
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ProctoringResponse.fromJson(data);
      }
      throw ApiError(message: 'Data aktivitas belum berhasil dikirim.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<SubmitResponse> submitExam(String attemptId) async {
    try {
      final response = await _dio.post<dynamic>('/attempts/$attemptId/submit');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return SubmitResponse.fromJson(data);
      }
      throw ApiError(message: 'Pengumpulan ujian belum berhasil.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<List<ResultResponse>> getMyResults() async {
    try {
      final response = await _dio.get<dynamic>('/results/me');
      final data = response.data;
      if (data is List<dynamic>) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(ResultResponse.fromJson)
            .toList();
      }
      throw ApiError(message: 'Hasil ujian belum bisa dimuat.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<List<ResultResponse>> getAdminResults() async {
    try {
      final response = await _dio.get<dynamic>('/results/admin');
      final data = response.data;
      if (data is List<dynamic>) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(ResultResponse.fromJson)
            .toList();
      }
      throw ApiError(message: 'Data hasil belum bisa dimuat.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }
}
