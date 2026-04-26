import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as path_util;

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

  Future<ApiExam> createExam({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? videoProvider,
    String? videoRoomId,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
    };
    if (videoProvider != null && videoProvider.trim().isNotEmpty) {
      payload['videoProvider'] = videoProvider.trim();
    }
    if (videoRoomId != null && videoRoomId.trim().isNotEmpty) {
      payload['videoRoomId'] = videoRoomId.trim();
    }

    try {
      final response = await _dio.post<dynamic>(
        '/exams',
        data: payload,
        options: _writeOptions(),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ApiExam.fromJson(data);
      }
      throw ApiError(message: 'Ujian belum berhasil dibuat.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<ApiExam> publishExam(String examId) async {
    try {
      final response = await _dio.post<dynamic>(
        '/exams/$examId/publish',
        options: _writeOptions(),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ApiExam.fromJson(data);
      }
      throw ApiError(message: 'Ujian belum berhasil dipublikasikan.');
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
      throw ApiError(message: 'Daftar ujian belum bisa dimuat.');
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
    required DateTime publishAt,
    required DateTime closeAt,
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
          'publishAt': publishAt.toUtc().toIso8601String(),
          'closeAt': closeAt.toUtc().toIso8601String(),
        },
        options: _writeOptions(),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ApiSubject.fromJson(data);
      }
      throw ApiError(message: 'Ujian belum berhasil disimpan.');
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
    required DateTime publishAt,
    required DateTime closeAt,
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
          'publishAt': publishAt.toUtc().toIso8601String(),
          'closeAt': closeAt.toUtc().toIso8601String(),
        },
        options: _writeOptions(),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ApiSubject.fromJson(data);
      }
      throw ApiError(message: 'Perubahan ujian belum berhasil disimpan.');
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
    required String subjectId,
    String? examId,
  }) async {
    final payload = <String, dynamic>{
      'subjectId': subjectId,
    };
    if (examId != null && examId.trim().isNotEmpty) {
      payload['examId'] = examId;
    }

    try {
      final response = await _dio.post<dynamic>(
        '/attempts/start',
        data: payload,
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

  Future<List<ActiveMonitoringAttempt>> listActiveMonitoringAttempts() async {
    try {
      final response = await _dio.get<dynamic>(
        '/attempts/active-monitoring',
        options: _readOptions(),
      );
      final data = response.data;
      if (data is List<dynamic>) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(ActiveMonitoringAttempt.fromJson)
            .where((item) => item.attemptId.trim().isNotEmpty)
            .toList();
      }
      throw ApiError(message: 'Data standby pengawas belum bisa dimuat.');
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

  Future<void> uploadProctoringAudioChunk({
    required String attemptId,
    required int chunkIndex,
    required DateTime startedAt,
    required DateTime endedAt,
    required String filePath,
    required String mimeType,
  }) async {
    final fileName = path_util.basename(filePath);
    final payload = FormData.fromMap(<String, dynamic>{
      'attemptId': attemptId,
      'chunkIndex': chunkIndex,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'endedAt': endedAt.toUtc().toIso8601String(),
      'mimeType': mimeType,
      'audio': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      ),
    });

    try {
      await _dio.post<dynamic>(
        '/proctoring/audio-chunks',
        data: payload,
        options: _proctoringOptions(),
      );
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<List<AttemptAudioChunk>> getAdminAttemptAudioChunks(
    String attemptId,
  ) async {
    try {
      final response = await _dio.get<dynamic>(
        '/proctoring/attempts/$attemptId/audio-chunks',
        options: _readOptions(),
      );
      final data = response.data;
      if (data is List<dynamic>) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(AttemptAudioChunk.fromJson)
            .toList();
      }
      throw ApiError(message: 'Daftar rekaman belum bisa dimuat.');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<Uint8List> downloadAdminAudioChunkFile(String chunkId) async {
    try {
      final response = await _dio.get<List<int>>(
        '/proctoring/audio-chunks/$chunkId/file',
        options: _readOptions().copyWith(
          responseType: ResponseType.bytes,
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw ApiError(message: 'File rekaman kosong.');
      }
      return Uint8List.fromList(bytes);
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
    return getAdminResultsWithFilter();
  }

  Future<List<ResultResponse>> getAdminResultsWithFilter({
    String? classId,
    String? examId,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (classId != null && classId.trim().isNotEmpty) {
      queryParameters['classId'] = classId.trim();
    }
    if (examId != null && examId.trim().isNotEmpty) {
      queryParameters['examId'] = examId.trim();
    }

    try {
      final response = await _dio.get<dynamic>(
        '/results/admin',
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
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

  Future<List<AdminAttemptAnswer>> getAdminAttemptAnswers(
      String attemptId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/attempts/$attemptId',
        options: _readOptions(),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw ApiError(message: 'Detail attempt tidak valid.');
      }

      final rawAnswers = data['answers'];
      if (rawAnswers is! List<dynamic>) {
        return const <AdminAttemptAnswer>[];
      }

      return rawAnswers
          .whereType<Map<String, dynamic>>()
          .map(AdminAttemptAnswer.fromJson)
          .where((answer) => answer.questionId.trim().isNotEmpty)
          .toList();
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<void> deleteAdminResult(String resultId) async {
    try {
      await _dio.delete<dynamic>(
        '/results/$resultId',
        options: _writeOptions(),
      );
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }
}
