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
      throw ApiError(message: 'Exam list response is invalid');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<List<ApiSubject>> listSubjects() async {
    try {
      final response = await _dio.get<dynamic>('/subjects');
      final data = response.data;
      if (data is List<dynamic>) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(ApiSubject.fromJson)
            .toList();
      }
      throw ApiError(message: 'Subject list response is invalid');
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
      throw ApiError(message: 'Start attempt response is invalid');
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
      throw ApiError(message: 'Attempt detail response is invalid');
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
      throw ApiError(message: 'Save answer response is invalid');
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
      throw ApiError(message: 'Proctoring response is invalid');
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
      throw ApiError(message: 'Submit response is invalid');
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
      throw ApiError(message: 'Results response is invalid');
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
      throw ApiError(message: 'Admin results response is invalid');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }
}
