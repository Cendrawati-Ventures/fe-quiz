import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device/idle_service.dart';
import '../../../core/device/lifecycle_service.dart';
import '../../../core/device/noise_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/queue/outbox_queue.dart';
import '../../../core/storage/app_preferences.dart';
import '../../../core/utils/debounce.dart';
import '../../../core/utils/time_sync.dart';
import '../model/exam_models.dart';
import '../service/exam_service.dart';

final examServiceProvider = Provider<ExamService>((ref) {
  final dio = ref.watch(apiClientProvider);
  return ExamService(dio);
});

final examListProvider = FutureProvider<List<ApiExam>>((ref) async {
  final service = ref.watch(examServiceProvider);
  return service.listExams();
});

final subjectListProvider = FutureProvider<List<ApiSubject>>((ref) async {
  final service = ref.watch(examServiceProvider);
  return service.listSubjects();
});

final myResultsProvider = FutureProvider<List<ResultResponse>>((ref) async {
  final service = ref.watch(examServiceProvider);
  return service.getMyResults();
});

final adminResultsProvider = FutureProvider<List<ResultResponse>>((ref) async {
  final service = ref.watch(examServiceProvider);
  return service.getAdminResults();
});

final examSessionProvider =
    NotifierProvider<ExamSessionNotifier, ExamSessionState>(
  ExamSessionNotifier.new,
);

enum SubmitState { idle, submitting, failed, success }

enum ConnectionStatus { unknown, online, offline }

enum SyncStatus { synced, pending, retrying }

class ExamSessionState {
  const ExamSessionState({
    this.isLoading = false,
    this.exam,
    this.subject,
    this.attempt,
    this.questions = const <ApiQuestion>[],
    this.currentQuestionIndex = 0,
    this.answersByQuestionId = const <String, dynamic>{},
    this.pendingAnswerQueue = const <OutboxItem>[],
    this.proctoringBuffer = const <ProctoringEventPayload>[],
    this.submitState = SubmitState.idle,
    this.connectionState = ConnectionStatus.unknown,
    this.syncStatus = SyncStatus.synced,
    this.serverOffsetMs = 0,
    this.remainingSeconds = 0,
    this.latestResult,
    this.warningMessage,
    this.errorMessage,
  });

  final bool isLoading;
  final ApiExam? exam;
  final ApiSubject? subject;
  final ApiAttempt? attempt;
  final List<ApiQuestion> questions;
  final int currentQuestionIndex;
  final Map<String, dynamic> answersByQuestionId;
  final List<OutboxItem> pendingAnswerQueue;
  final List<ProctoringEventPayload> proctoringBuffer;
  final SubmitState submitState;
  final ConnectionStatus connectionState;
  final SyncStatus syncStatus;
  final int serverOffsetMs;
  final int remainingSeconds;
  final ResultResponse? latestResult;
  final String? warningMessage;
  final String? errorMessage;

  bool get hasActiveAttempt => attempt?.status == AttemptStatus.inProgress;

  ApiQuestion? get currentQuestion {
    if (questions.isEmpty) {
      return null;
    }
    final safeIndex = currentQuestionIndex.clamp(0, questions.length - 1);
    return questions[safeIndex];
  }

  int get unansweredCount {
    return questions.where((question) {
      final answer = answersByQuestionId[question.id];
      if (answer == null) {
        return true;
      }
      if (answer is String) {
        return answer.trim().isEmpty;
      }
      if (answer is List<dynamic>) {
        return answer.isEmpty;
      }
      if (answer is Map<String, dynamic>) {
        return answer.isEmpty;
      }
      return false;
    }).length;
  }

  ExamSessionState copyWith({
    bool? isLoading,
    ApiExam? exam,
    ApiSubject? subject,
    ApiAttempt? attempt,
    List<ApiQuestion>? questions,
    int? currentQuestionIndex,
    Map<String, dynamic>? answersByQuestionId,
    List<OutboxItem>? pendingAnswerQueue,
    List<ProctoringEventPayload>? proctoringBuffer,
    SubmitState? submitState,
    ConnectionStatus? connectionState,
    SyncStatus? syncStatus,
    int? serverOffsetMs,
    int? remainingSeconds,
    ResultResponse? latestResult,
    bool clearLatestResult = false,
    String? warningMessage,
    bool clearWarningMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ExamSessionState(
      isLoading: isLoading ?? this.isLoading,
      exam: exam ?? this.exam,
      subject: subject ?? this.subject,
      attempt: attempt ?? this.attempt,
      questions: questions ?? this.questions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      answersByQuestionId: answersByQuestionId ?? this.answersByQuestionId,
      pendingAnswerQueue: pendingAnswerQueue ?? this.pendingAnswerQueue,
      proctoringBuffer: proctoringBuffer ?? this.proctoringBuffer,
      submitState: submitState ?? this.submitState,
      connectionState: connectionState ?? this.connectionState,
      syncStatus: syncStatus ?? this.syncStatus,
      serverOffsetMs: serverOffsetMs ?? this.serverOffsetMs,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      latestResult:
          clearLatestResult ? null : (latestResult ?? this.latestResult),
      warningMessage:
          clearWarningMessage ? null : (warningMessage ?? this.warningMessage),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'exam': exam?.toJson(),
      'subject': subject?.toJson(),
      'attempt': attempt?.toJson(),
      'questions': questions.map((question) => question.toJson()).toList(),
      'currentQuestionIndex': currentQuestionIndex,
      'answersByQuestionId': answersByQuestionId,
      'proctoringBuffer':
          proctoringBuffer.map((event) => event.toJson()).toList(),
      'submitState': submitState.name,
      'connectionState': connectionState.name,
      'syncStatus': syncStatus.name,
      'serverOffsetMs': serverOffsetMs,
      'remainingSeconds': remainingSeconds,
      'latestResult': latestResult?.toJson(),
    };
  }

  factory ExamSessionState.fromJson(Map<String, dynamic> json) {
    final rawQuestions = (json['questions'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ApiQuestion.fromJson)
        .toList();
    final rawProctoring =
        (json['proctoringBuffer'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(ProctoringEventPayload.fromJson)
            .toList();
    final rawAnswers = (json['answersByQuestionId'] as Map<String, dynamic>?) ??
        <String, dynamic>{};

    return ExamSessionState(
      exam: (json['exam'] as Map<String, dynamic>?) == null
          ? null
          : ApiExam.fromJson(json['exam'] as Map<String, dynamic>),
      subject: (json['subject'] as Map<String, dynamic>?) == null
          ? null
          : ApiSubject.fromJson(json['subject'] as Map<String, dynamic>),
      attempt: (json['attempt'] as Map<String, dynamic>?) == null
          ? null
          : ApiAttempt.fromJson(json['attempt'] as Map<String, dynamic>),
      questions: rawQuestions,
      currentQuestionIndex: json['currentQuestionIndex'] as int? ?? 0,
      answersByQuestionId: rawAnswers,
      proctoringBuffer: rawProctoring,
      submitState: SubmitState.values.firstWhere(
        (value) => value.name == json['submitState'],
        orElse: () => SubmitState.idle,
      ),
      connectionState: ConnectionStatus.values.firstWhere(
        (value) => value.name == json['connectionState'],
        orElse: () => ConnectionStatus.unknown,
      ),
      syncStatus: SyncStatus.values.firstWhere(
        (value) => value.name == json['syncStatus'],
        orElse: () => SyncStatus.synced,
      ),
      serverOffsetMs: json['serverOffsetMs'] as int? ?? 0,
      remainingSeconds: json['remainingSeconds'] as int? ?? 0,
      latestResult: (json['latestResult'] as Map<String, dynamic>?) == null
          ? null
          : ResultResponse.fromJson(
              json['latestResult'] as Map<String, dynamic>,
            ),
    );
  }
}

class ExamSessionNotifier extends Notifier<ExamSessionState> {
  static const String _sessionStateKey = 'exam_session_state_v1';
  static const Duration _saveDebounce = Duration(milliseconds: 700);
  static const Duration _idleTimeout = Duration(seconds: 30);
  static const Duration _noiseInterval = Duration(seconds: 20);

  late final ExamService _service;
  late final OutboxQueue _queue;
  late final AppPreferences _preferences;
  final TimeSync _timeSync = TimeSync();
  late final Debouncer _saveDebouncer;

  Timer? _countdownTimer;
  LifecycleService? _lifecycleService;
  StreamSubscription<AppLifecycleState>? _lifecycleSubscription;
  IdleService? _idleService;
  NoiseService? _noiseService;
  bool _isFlushing = false;

  @override
  ExamSessionState build() {
    _service = ref.read(examServiceProvider);
    _queue = ref.read(outboxQueueProvider);
    _preferences = ref.read(appPreferencesProvider);
    _saveDebouncer = Debouncer(_saveDebounce);

    ref.onDispose(() {
      _saveDebouncer.dispose();
      _disposeRuntimeServices();
    });

    Future<void>(() async {
      await _restoreSession();
      await _refreshQueueSnapshot();
      if (state.hasActiveAttempt) {
        _startRuntimeServices();
        await recoverActiveAttempt();
        await flushOutbox();
      }
    });

    return const ExamSessionState();
  }

  Future<void> startAttempt({
    required ApiExam exam,
    required ApiSubject subject,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearWarningMessage: true,
      clearLatestResult: true,
      submitState: SubmitState.idle,
    );

    try {
      final response = await _service.startAttempt(
        examId: exam.id,
        subjectId: subject.id,
      );

      _timeSync.syncFromServerUtc(response.attempt.startTime.toUtc());
      state = state.copyWith(
        isLoading: false,
        exam: exam,
        subject: subject,
        attempt: response.attempt,
        questions: response.questions,
        currentQuestionIndex: 0,
        answersByQuestionId: <String, dynamic>{},
        proctoringBuffer: <ProctoringEventPayload>[],
        serverOffsetMs: _timeSync.serverOffsetMs,
        submitState: SubmitState.idle,
        syncStatus: SyncStatus.synced,
        connectionState: ConnectionStatus.online,
        clearErrorMessage: true,
        clearWarningMessage: true,
      );

      await _queue.clearByAttempt(response.attempt.id);
      await _refreshQueueSnapshot();
      _startRuntimeServices();
      _recalculateTimer();
      await _persistSession();
    } on ApiError catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.message,
        submitState: SubmitState.failed,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to start attempt',
        submitState: SubmitState.failed,
      );
    }
  }

  Future<void> recoverActiveAttempt() async {
    final attempt = state.attempt;
    if (attempt == null) {
      return;
    }

    try {
      final detail = await _service.getAttemptById(attempt.id);
      if (detail.attempt.status != AttemptStatus.inProgress) {
        await clearSession();
        return;
      }

      var questions = state.questions;
      if (questions.isEmpty && state.exam != null && state.subject != null) {
        final restarted = await _service.startAttempt(
          examId: state.exam!.id,
          subjectId: state.subject!.id,
        );
        questions = restarted.questions;
      }

      final answers = Map<String, dynamic>.from(state.answersByQuestionId);
      for (final answer in detail.answers) {
        answers[answer.questionId] = answer.answer;
      }

      state = state.copyWith(
        attempt: detail.attempt,
        questions: questions,
        answersByQuestionId: answers,
        connectionState: ConnectionStatus.online,
        clearErrorMessage: true,
      );
      _recalculateTimer();
      await _persistSession();
    } on ApiError catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await clearSession();
        return;
      }
      state = state.copyWith(errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(errorMessage: 'Failed to recover active attempt');
    }
  }

  Future<void> answerQuestion({
    required String questionId,
    required Object? answer,
  }) async {
    final attempt = state.attempt;
    if (attempt == null) {
      return;
    }

    final updated = Map<String, dynamic>.from(state.answersByQuestionId);
    updated[questionId] = answer;
    state = state.copyWith(
      answersByQuestionId: updated,
      syncStatus: SyncStatus.pending,
      clearErrorMessage: true,
    );

    await _queue.enqueueAnswer(
      attemptId: attempt.id,
      questionId: questionId,
      answer: answer,
    );
    await _refreshQueueSnapshot();
    await _persistSession();

    _saveDebouncer.run(() async {
      await flushOutbox();
    });
  }

  void onUserInteraction() {
    _idleService?.reset();
  }

  void nextQuestion() {
    if (state.questions.isEmpty) {
      return;
    }
    final next =
        min(state.questions.length - 1, state.currentQuestionIndex + 1);
    state = state.copyWith(currentQuestionIndex: next);
  }

  void previousQuestion() {
    if (state.questions.isEmpty) {
      return;
    }
    final previous = max(0, state.currentQuestionIndex - 1);
    state = state.copyWith(currentQuestionIndex: previous);
  }

  void selectQuestion(int index) {
    if (state.questions.isEmpty) {
      return;
    }
    final safe = index.clamp(0, state.questions.length - 1);
    state = state.copyWith(currentQuestionIndex: safe);
  }

  Future<void> submitAttempt() async {
    final attempt = state.attempt;
    if (attempt == null || state.submitState == SubmitState.submitting) {
      return;
    }

    state = state.copyWith(
      submitState: SubmitState.submitting,
      isLoading: true,
      clearErrorMessage: true,
      clearWarningMessage: true,
    );

    await flushOutbox();
    await _queue.enqueueSubmit(attemptId: attempt.id);
    await _refreshQueueSnapshot();
    await flushOutbox();

    if (state.submitState != SubmitState.success) {
      state = state.copyWith(
        submitState: SubmitState.failed,
        isLoading: false,
        errorMessage: state.errorMessage ?? 'Submit failed. Please retry.',
      );
      await _persistSession();
    }
  }

  Future<void> flushOutbox() async {
    if (_isFlushing) {
      return;
    }
    _isFlushing = true;
    try {
      final dueItems = await _queue.getDueItems();
      if (dueItems.isEmpty) {
        await _refreshQueueSnapshot();
        return;
      }

      for (final item in dueItems) {
        try {
          await _handleOutboxItem(item);
          await _queue.markSuccess(item.id);
          state = state.copyWith(
            connectionState: ConnectionStatus.online,
            syncStatus: SyncStatus.synced,
            clearErrorMessage: true,
          );
        } on ApiError catch (error) {
          await _queue.markFailure(item.id);
          state = state.copyWith(
            connectionState: _resolveConnectionStatus(error),
            syncStatus: SyncStatus.retrying,
            errorMessage: error.message,
          );
        } catch (_) {
          await _queue.markFailure(item.id);
          state = state.copyWith(
            connectionState: ConnectionStatus.offline,
            syncStatus: SyncStatus.retrying,
            errorMessage: 'Network sync failed, retrying in background.',
          );
        }
      }

      await _refreshQueueSnapshot();
      _recalculateTimer();
      await _persistSession();
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> clearSession() async {
    _disposeRuntimeServices();
    await _queue.clear();
    await _preferences.remove(_sessionStateKey);
    state = const ExamSessionState();
  }

  Future<void> _handleOutboxItem(OutboxItem item) async {
    switch (item.type) {
      case OutboxItemType.answer:
        await _service.saveAnswer(
          attemptId: item.payload['attemptId'] as String,
          questionId: item.payload['questionId'] as String,
          answer: item.payload['answer'],
        );
        return;
      case OutboxItemType.proctoring:
        final event = ProctoringEventPayload.fromJson(
          <String, dynamic>{
            'attemptId': item.payload['attemptId'],
            'type': item.payload['type'],
            'value': item.payload['value'],
            'timestamp': item.payload['timestamp'],
          },
        );
        await _service.sendProctoringEvents(<ProctoringEventPayload>[event]);
        return;
      case OutboxItemType.submit:
        final response = await _service.submitExam(
          item.payload['attemptId'] as String,
        );
        final updatedAttempt = state.attempt?.copyWith(
          status: AttemptStatus.submitted,
          endTime: DateTime.now().toUtc(),
        );
        state = state.copyWith(
          latestResult: response.toResultResponse(),
          submitState: SubmitState.success,
          attempt: updatedAttempt,
          isLoading: false,
          syncStatus: SyncStatus.synced,
          clearWarningMessage: true,
          clearErrorMessage: true,
        );
        _disposeRuntimeServices();
        await _queue.clearByAttempt(response.attemptId);
        return;
    }
  }

  Future<void> _enqueueProctoringEvent({
    required ProctoringEventType type,
    required int value,
    String? warning,
  }) async {
    final attempt = state.attempt;
    if (attempt == null || attempt.status != AttemptStatus.inProgress) {
      return;
    }

    final now = _timeSync.nowServerUtc();
    final event = ProctoringEventPayload(
      attemptId: attempt.id,
      type: type,
      value: value.clamp(0, 100),
      timestamp: now,
    );

    final buffer = List<ProctoringEventPayload>.from(state.proctoringBuffer)
      ..add(event);
    final cappedBuffer =
        buffer.length > 100 ? buffer.sublist(buffer.length - 100) : buffer;
    state = state.copyWith(
      proctoringBuffer: cappedBuffer,
      warningMessage: warning,
      syncStatus: SyncStatus.pending,
    );

    await _queue.enqueueProctoring(
      attemptId: event.attemptId,
      type: proctoringEventTypeToString(event.type),
      value: event.value,
      timestamp: event.timestamp.toIso8601String(),
    );
    await _refreshQueueSnapshot();
    await _persistSession();
    await flushOutbox();
  }

  Future<void> _restoreSession() async {
    final raw = await _preferences.getString(_sessionStateKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        state = ExamSessionState.fromJson(decoded);
        _timeSync.syncFromServerEpochMs(
          DateTime.now().toUtc().millisecondsSinceEpoch + state.serverOffsetMs,
        );
        _recalculateTimer();
      }
    } catch (_) {
      await _preferences.remove(_sessionStateKey);
    }
  }

  Future<void> _persistSession() async {
    await _preferences.setString(_sessionStateKey, jsonEncode(state.toJson()));
  }

  Future<void> _refreshQueueSnapshot() async {
    final queueItems = await _queue.getItems();
    state = state.copyWith(pendingAnswerQueue: queueItems);
  }

  ConnectionStatus _resolveConnectionStatus(ApiError error) {
    if (error.statusCode == null) {
      return ConnectionStatus.offline;
    }
    if (error.statusCode! >= 500) {
      return ConnectionStatus.offline;
    }
    return ConnectionStatus.online;
  }

  void _startRuntimeServices() {
    _disposeRuntimeServices();
    _startCountdown();

    _lifecycleService = LifecycleService();
    _lifecycleSubscription = _lifecycleService!.stream.listen((state) async {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive ||
          state == AppLifecycleState.detached) {
        await _enqueueProctoringEvent(
          type: ProctoringEventType.appBackground,
          value: 100,
          warning: 'Aplikasi berpindah ke background terdeteksi.',
        );
      }
    });

    _idleService = IdleService(
      timeout: _idleTimeout,
      onIdle: () async {
        await _enqueueProctoringEvent(
          type: ProctoringEventType.idle,
          value: min(100, _idleTimeout.inSeconds),
          warning: 'Kamu tidak aktif.',
        );
      },
    )..start();

    _noiseService = NoiseService(
      interval: _noiseInterval,
      onNoise: (value) async {
        await _enqueueProctoringEvent(
          type: ProctoringEventType.noise,
          value: value,
          warning: value >= 70 ? 'Noise level tinggi terdeteksi.' : null,
        );
      },
    )..start();
  }

  void _disposeRuntimeServices() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _lifecycleSubscription?.cancel();
    _lifecycleSubscription = null;
    _lifecycleService?.dispose();
    _lifecycleService = null;
    _idleService?.stop();
    _idleService = null;
    _noiseService?.stop();
    _noiseService = null;
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _recalculateTimer();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      _recalculateTimer();
      if (state.hasActiveAttempt && state.remainingSeconds <= 0) {
        state = state.copyWith(
          warningMessage: 'Waktu habis. Jawaban sedang dikumpulkan otomatis.',
        );
        await submitAttempt();
      }
    });
  }

  void _recalculateTimer() {
    final attempt = state.attempt;
    final subject = state.subject;
    final exam = state.exam;
    if (attempt == null || subject == null || exam == null) {
      state = state.copyWith(remainingSeconds: 0);
      return;
    }

    final startedAt = attempt.startTime.toUtc();
    final bySubject = startedAt.add(Duration(minutes: subject.durationMinutes));
    final byExam = exam.endTime.toUtc();
    final hardDeadline = bySubject.isBefore(byExam) ? bySubject : byExam;
    final nowServer = DateTime.now()
        .toUtc()
        .add(Duration(milliseconds: state.serverOffsetMs));
    final seconds = max(
      0,
      hardDeadline.difference(nowServer).inSeconds,
    );
    state = state.copyWith(remainingSeconds: seconds);
  }
}
