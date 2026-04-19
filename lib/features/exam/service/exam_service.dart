import 'package:dio/dio.dart';

import '../../../core/network/api_error.dart';
import '../model/exam_models.dart';

class ExamService {
  ExamService(this._dio);

  final Dio _dio;
  static const Duration _readConnectTimeout = Duration(seconds: 10);
  static const Duration _readSendTimeout = Duration(seconds: 10);
  static const Duration _readReceiveTimeout = Duration(seconds: 15);
  static const Duration _writeConnectTimeout = Duration(seconds: 10);
  static const Duration _writeSendTimeout = Duration(seconds: 10);
  static const Duration _writeReceiveTimeout = Duration(seconds: 15);
  static const Duration _startAttemptConnectTimeout = Duration(seconds: 8);
  static const Duration _startAttemptSendTimeout = Duration(seconds: 8);
  static const Duration _startAttemptReceiveTimeout = Duration(seconds: 15);
  static const Duration _saveAnswerConnectTimeout = Duration(seconds: 5);
  static const Duration _saveAnswerSendTimeout = Duration(seconds: 5);
  static const Duration _saveAnswerReceiveTimeout = Duration(seconds: 8);
  static const Duration _proctoringConnectTimeout = Duration(seconds: 5);
  static const Duration _proctoringSendTimeout = Duration(seconds: 5);
  static const Duration _proctoringReceiveTimeout = Duration(seconds: 8);
  static const Duration _submitConnectTimeout = Duration(seconds: 8);
  static const Duration _submitSendTimeout = Duration(seconds: 8);
  static const Duration _submitReceiveTimeout = Duration(seconds: 40);

  Dio get client => _dio;

  Options _readOptions() {
    return Options(
      connectTimeout: _readConnectTimeout,
      sendTimeout: _readSendTimeout,
      receiveTimeout: _readReceiveTimeout,
    );
  }

  Options _writeOptions() {
    return Options(
      connectTimeout: _writeConnectTimeout,
      sendTimeout: _writeSendTimeout,
      receiveTimeout: _writeReceiveTimeout,
    );
  }

  Options _startAttemptOptions() {
    return Options(
      connectTimeout: _startAttemptConnectTimeout,
      sendTimeout: _startAttemptSendTimeout,
      receiveTimeout: _startAttemptReceiveTimeout,
    );
  }

  Options _saveAnswerOptions() {
    return Options(
      connectTimeout: _saveAnswerConnectTimeout,
      sendTimeout: _saveAnswerSendTimeout,
      receiveTimeout: _saveAnswerReceiveTimeout,
    );
  }

  Options _proctoringOptions() {
    return Options(
      connectTimeout: _proctoringConnectTimeout,
      sendTimeout: _proctoringSendTimeout,
      receiveTimeout: _proctoringReceiveTimeout,
    );
  }

  Options _submitOptions() {
    return Options(
      connectTimeout: _submitConnectTimeout,
      sendTimeout: _submitSendTimeout,
      receiveTimeout: _submitReceiveTimeout,
    );
  }

  Future<List<ApiExam>> listExams() async {
    try {
      final response = await _dio.get<dynamic>(
        '/exams',
        options: _readOptions(),
      );
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
      final response = await _dio.get<dynamic>(
        '/api/subjects',
        options: _readOptions(),
      );
      final data = response.data;
      if (data is List<dynamic>) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(ApiSubject.fromJson)
            .toList();
      }
      throw ApiError(message: 'Daftar mata pelajaran belum bisa dimuat.');
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
        options: _writeOptions(),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ApiSubject.fromJson(data);
      }
      throw ApiError(message: 'Mata pelajaran belum berhasil disimpan.');
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
        options: _writeOptions(),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ApiSubject.fromJson(data);
      }
      throw ApiError(
          message: 'Perubahan mata pelajaran belum berhasil disimpan.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<void> deleteSubject(String id) async {
    try {
      await _dio.delete<dynamic>(
        '/api/subjects/$id',
        options: _writeOptions(),
      );
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<List<AdminQuestion>> listQuestionsBySubject(String subjectId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/subjects/$subjectId/questions',
        options: _readOptions(),
      );
      final data = response.data;
      if (data is List<dynamic>) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(AdminQuestion.fromJson)
            .toList();
      }
      throw ApiError(message: 'Daftar pertanyaan belum bisa dimuat.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<AdminQuestion> createQuestion({
    required String subjectId,
    required QuestionType type,
    required String text,
    required num weight,
    required Object options,
    required Object correctAnswer,
    String? imageData,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/questions',
        data: <String, dynamic>{
          'subjectId': subjectId,
          'type': questionTypeToString(type),
          'text': text,
          'options': options,
          'correctAnswer': correctAnswer,
          'imageData': imageData,
          'weight': weight,
        },
        options: _writeOptions(),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AdminQuestion.fromJson(data);
      }
      throw ApiError(message: 'Pertanyaan belum berhasil dibuat.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<AdminQuestion> updateQuestion({
    required String id,
    required QuestionType type,
    required String text,
    required num weight,
    required Object options,
    required Object correctAnswer,
    String? imageData,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        '/api/questions/$id',
        data: <String, dynamic>{
          'type': questionTypeToString(type),
          'text': text,
          'options': options,
          'correctAnswer': correctAnswer,
          'imageData': imageData,
          'weight': weight,
        },
        options: _writeOptions(),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AdminQuestion.fromJson(data);
      }
      throw ApiError(message: 'Perubahan pertanyaan belum berhasil disimpan.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<void> deleteQuestion(String id) async {
    try {
      await _dio.delete<dynamic>(
        '/api/questions/$id',
        options: _writeOptions(),
      );
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<List<AdminQuestion>> reorderQuestions({
    required String subjectId,
    required List<String> orderedQuestionIds,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        '/api/questions/reorder',
        data: <String, dynamic>{
          'subjectId': subjectId,
          'orderedQuestionIds': orderedQuestionIds,
        },
        options: _writeOptions(),
      );
      final data = response.data;
      if (data is List<dynamic>) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(AdminQuestion.fromJson)
            .toList();
      }
      throw ApiError(message: 'Urutan pertanyaan belum berhasil diperbarui.');
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
        options: _startAttemptOptions(),
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
      final response = await _dio.get<dynamic>(
        '/attempts/$attemptId',
        options: _readOptions(),
      );
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
        options: _saveAnswerOptions(),
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
        options: _proctoringOptions(),
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
      final response = await _dio.post<dynamic>(
        '/attempts/$attemptId/submit',
        options: _submitOptions(),
      );
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
      final response = await _dio.get<dynamic>(
        '/results/me',
        options: _readOptions(),
      );
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
      final response = await _dio.get<dynamic>(
        '/results/admin',
        options: _readOptions(),
      );
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
