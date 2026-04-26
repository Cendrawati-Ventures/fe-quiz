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

class GroupSubQuestion {
  const GroupSubQuestion({
    required this.id,
    required this.text,
    required this.type,
    required this.options,
  });

  final String id;
  final String text;
  final QuestionType type;
  final Object? options;
}

List<GroupSubQuestion> extractGroupSubQuestions(Object? options) {
  final result = <GroupSubQuestion>[];

  void addFromEntry({
    required Object? raw,
    required String fallbackId,
  }) {
    if (raw is! Map<String, dynamic>) {
      return;
    }
    if (!_looksLikeSubQuestion(raw)) {
      return;
    }
    final id = _extractSubQuestionId(raw, fallbackId);
    final text = _extractSubQuestionText(raw, id);
    final type = _extractSubQuestionType(raw);
    final subOptions = raw['options'] ?? raw['choices'] ?? raw['answers'];
    result.add(
      GroupSubQuestion(
        id: id,
        text: text,
        type: type,
        options: subOptions,
      ),
    );
  }

  void addFromList(List<dynamic> list, String prefix) {
    for (var i = 0; i < list.length; i++) {
      addFromEntry(raw: list[i], fallbackId: '$prefix-$i');
    }
  }

  void addFromMap(Map<String, dynamic> map, String prefix) {
    final knownKeys = <String>[
      'subQuestions',
      'sub_questions',
      'subquestions',
      'questions',
      'children',
      'items',
      'parts',
    ];

    for (final key in knownKeys) {
      final candidate = map[key];
      if (candidate is List<dynamic>) {
        addFromList(candidate, key);
        if (result.isNotEmpty) {
          return;
        }
      }
      if (candidate is Map<String, dynamic>) {
        var index = 0;
        for (final entry in candidate.entries) {
          addFromEntry(
            raw: <String, dynamic>{
              ...?((entry.value is Map<String, dynamic>)
                  ? entry.value as Map<String, dynamic>
                  : null),
              if (entry.value is! Map<String, dynamic>) 'text': entry.value,
              'id': entry.key,
            },
            fallbackId: '$key-$index',
          );
          index++;
        }
        if (result.isNotEmpty) {
          return;
        }
      }
    }

    var index = 0;
    for (final entry in map.entries) {
      if (entry.value is Map<String, dynamic>) {
        addFromEntry(
          raw: <String, dynamic>{
            ...(entry.value as Map<String, dynamic>),
            if (!(entry.value as Map<String, dynamic>).containsKey('id'))
              'id': entry.key,
          },
          fallbackId: '$prefix-$index',
        );
      }
      index++;
    }
  }

  if (options is List<dynamic>) {
    addFromList(options, 'list');
  } else if (options is Map<String, dynamic>) {
    addFromMap(options, 'map');
  }

  return result;
}

String? extractGroupParentText(Object? options) {
  if (options is! Map<String, dynamic>) {
    return null;
  }
  final parentKeys = <String>[
    'parent',
    'parentText',
    'passage',
    'context',
    'stem',
    'description',
    'instruction',
  ];
  for (final key in parentKeys) {
    final value = options[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

Map<String, dynamic> normalizeGroupAnswerMap(Object? rawAnswer) {
  final normalized = <String, dynamic>{};

  bool hasValue(Object? value) {
    if (value == null) {
      return false;
    }
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    if (value is List<dynamic>) {
      return value.isNotEmpty;
    }
    if (value is Map<String, dynamic>) {
      return value.isNotEmpty;
    }
    return true;
  }

  if (rawAnswer is Map<String, dynamic>) {
    rawAnswer.forEach((key, value) {
      if (hasValue(value)) {
        normalized[key] = value;
      }
    });
    return normalized;
  }

  if (rawAnswer is List<dynamic>) {
    for (final entry in rawAnswer) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }
      final id = (entry['id'] ??
              entry['questionId'] ??
              entry['subQuestionId'] ??
              entry['key'])
          ?.toString();
      if (id == null || id.isEmpty) {
        continue;
      }
      final value = entry['answer'] ?? entry['value'];
      if (hasValue(value)) {
        normalized[id] = value;
      }
    }
  }

  return normalized;
}

String _extractSubQuestionId(Map<String, dynamic> raw, String fallbackId) {
  final candidate =
      raw['id'] ?? raw['questionId'] ?? raw['subQuestionId'] ?? raw['key'];
  final value = candidate?.toString() ?? fallbackId;
  return value.trim().isEmpty ? fallbackId : value;
}

String _extractSubQuestionText(Map<String, dynamic> raw, String fallbackId) {
  final text = raw['text'] ?? raw['question'] ?? raw['label'] ?? raw['title'];
  final stringValue = text?.toString();
  if (stringValue == null || stringValue.trim().isEmpty) {
    return 'Subsoal $fallbackId';
  }
  return stringValue.trim();
}

QuestionType _extractSubQuestionType(Map<String, dynamic> raw) {
  final typeRaw = raw['type']?.toString().toLowerCase();
  if (typeRaw == 'multi') {
    return QuestionType.multi;
  }
  return QuestionType.single;
}

bool _looksLikeSubQuestion(Map<String, dynamic> raw) {
  if (raw.containsKey('options') || raw.containsKey('choices')) {
    return true;
  }

  final hasQuestionText = (raw['text'] ?? raw['question'] ?? raw['label'])
      ?.toString()
      .trim()
      .isNotEmpty;
  return hasQuestionText == true;
}

class ExamSessionState {
  const ExamSessionState({
    this.isLoading = false,
    this.exam,
    this.subject,
    this.attempt,
    this.monitoring,
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
    this.serverDeadlineEpochMs,
    this.monitoringPrecheckConfirmed = false,
    this.latestResult,
    this.warningMessage,
    this.errorMessage,
  });

  final bool isLoading;
  final ApiExam? exam;
  final ApiSubject? subject;
  final ApiAttempt? attempt;
  final AttemptMonitoringConfig? monitoring;
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
  final int? serverDeadlineEpochMs;
  final bool monitoringPrecheckConfirmed;
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
      if (question.type == QuestionType.group) {
        final groupSubQuestions = extractGroupSubQuestions(question.options);
        final groupAnswer = normalizeGroupAnswerMap(answer);

        if (groupSubQuestions.isEmpty) {
          return groupAnswer.isEmpty;
        }

        for (final subQuestion in groupSubQuestions) {
          final subAnswer = groupAnswer[subQuestion.id];
          if (subAnswer == null) {
            return true;
          }
          if (subAnswer is String && subAnswer.trim().isEmpty) {
            return true;
          }
          if (subAnswer is List<dynamic> && subAnswer.isEmpty) {
            return true;
          }
          if (subAnswer is Map<String, dynamic> && subAnswer.isEmpty) {
            return true;
          }
        }
        return false;
      }

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
    AttemptMonitoringConfig? monitoring,
    bool clearMonitoring = false,
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
    int? serverDeadlineEpochMs,
    bool clearServerDeadline = false,
    bool? monitoringPrecheckConfirmed,
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
      monitoring: clearMonitoring ? null : (monitoring ?? this.monitoring),
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
      serverDeadlineEpochMs: clearServerDeadline
          ? null
          : (serverDeadlineEpochMs ?? this.serverDeadlineEpochMs),
      monitoringPrecheckConfirmed:
          monitoringPrecheckConfirmed ?? this.monitoringPrecheckConfirmed,
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
      'monitoring': monitoring?.toJson(),
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
      'serverDeadlineEpochMs': serverDeadlineEpochMs,
      'monitoringPrecheckConfirmed': monitoringPrecheckConfirmed,
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
      monitoring: (json['monitoring'] as Map<String, dynamic>?) == null
          ? null
          : AttemptMonitoringConfig.fromJson(
              json['monitoring'] as Map<String, dynamic>,
            ),
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
      serverDeadlineEpochMs: (json['serverDeadlineEpochMs'] as num?)?.toInt(),
      monitoringPrecheckConfirmed:
          json['monitoringPrecheckConfirmed'] as bool? ?? false,
      latestResult: (json['latestResult'] as Map<String, dynamic>?) == null
          ? null
          : ResultResponse.fromJson(
              json['latestResult'] as Map<String, dynamic>,
            ),
    );
  }
}

class ExamSessionNotifier extends Notifier<ExamSessionState> {
  static const String _sessionStateKey = 'exam_session_state_v3';
  static const Duration _saveDebounce = Duration(milliseconds: 700);
  static const Duration _idleTimeout = Duration(seconds: 30);
  static const Duration _noiseInterval = Duration(seconds: 20);

  late final ExamService _service;
  late final OutboxQueue _queue;
  late final AppPreferences _preferences;
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
    required ApiSubject subject,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearMonitoring: true,
      clearErrorMessage: true,
      clearWarningMessage: true,
      clearLatestResult: true,
      submitState: SubmitState.idle,
    );

    try {
      final response = await _service.startAttempt(
        subjectId: subject.id,
      );
      final serverOffsetMs = _serverOffsetFrom(response.serverNow);
      final serverDeadlineEpochMs = _resolveServerDeadlineEpochMs(
        serverNow: response.serverNow,
        remainingSeconds: response.remainingSeconds,
      );

      state = state.copyWith(
        isLoading: false,
        exam: null,
        subject: subject,
        attempt: response.attempt,
        monitoring: response.monitoring,
        questions: response.questions,
        currentQuestionIndex: 0,
        answersByQuestionId: <String, dynamic>{},
        proctoringBuffer: <ProctoringEventPayload>[],
        serverOffsetMs: serverOffsetMs,
        remainingSeconds: response.remainingSeconds ?? 0,
        serverDeadlineEpochMs: serverDeadlineEpochMs,
        clearServerDeadline: serverDeadlineEpochMs == null,
        monitoringPrecheckConfirmed: false,
        submitState: SubmitState.idle,
        syncStatus: SyncStatus.synced,
        connectionState: ConnectionStatus.online,
        clearErrorMessage: true,
        clearWarningMessage: true,
      );

      await _queue.clearByAttempt(response.attempt.id);
      await _clearOutboxFromOtherAttempts(response.attempt.id);
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
        errorMessage: 'Ujian belum bisa dimulai. Coba lagi.',
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
      if (questions.isEmpty && state.subject != null) {
        final restarted = await _service.startAttempt(
          subjectId: state.subject!.id,
        );
        questions = restarted.questions;
      }

      final answers = Map<String, dynamic>.from(state.answersByQuestionId);
      for (final answer in detail.answers) {
        answers[answer.questionId] = answer.answer;
      }
      final recoveredServerDeadlineEpochMs = _resolveServerDeadlineEpochMs(
        serverNow: detail.serverNow,
        remainingSeconds: detail.remainingSeconds,
      );

      state = state.copyWith(
        attempt: detail.attempt,
        monitoring: detail.monitoring ?? state.monitoring,
        questions: questions,
        answersByQuestionId: answers,
        serverOffsetMs: _serverOffsetFrom(detail.serverNow),
        remainingSeconds: detail.remainingSeconds ?? state.remainingSeconds,
        serverDeadlineEpochMs: recoveredServerDeadlineEpochMs,
        clearServerDeadline: recoveredServerDeadlineEpochMs == null,
        monitoringPrecheckConfirmed: state.monitoringPrecheckConfirmed,
        connectionState: ConnectionStatus.online,
        clearErrorMessage: true,
      );
      _recalculateTimer();
      await _persistSession();
    } on ApiError catch (error) {
      if (_shouldResetSessionFromApiError(error)) {
        await clearSession();
        return;
      }
      state = state.copyWith(errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(errorMessage: 'Sesi ujian belum bisa dipulihkan.');
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

    ApiQuestion? question;
    for (final item in state.questions) {
      if (item.id == questionId) {
        question = item;
        break;
      }
    }
    final normalizedAnswer = question?.type == QuestionType.group
        ? normalizeGroupAnswerMap(answer)
        : answer;

    final updated = Map<String, dynamic>.from(state.answersByQuestionId);
    updated[questionId] = normalizedAnswer;
    state = state.copyWith(
      answersByQuestionId: updated,
      syncStatus: SyncStatus.pending,
      clearErrorMessage: true,
    );

    await _queue.enqueueAnswer(
      attemptId: attempt.id,
      questionId: questionId,
      answer: normalizedAnswer,
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

  Future<void> reportProctoringSignal({
    required ProctoringEventType type,
    int value = 100,
    String? warning,
  }) async {
    await _enqueueProctoringEvent(
      type: type,
      value: value,
      warning: warning,
    );
  }

  void nextQuestion() {
    if (state.questions.isEmpty) {
      return;
    }
    final next =
        min(state.questions.length - 1, state.currentQuestionIndex + 1);
    state = state.copyWith(currentQuestionIndex: next);
  }

  Future<void> markMonitoringPrecheckConfirmed() async {
    if (state.monitoringPrecheckConfirmed) {
      return;
    }

    state = state.copyWith(monitoringPrecheckConfirmed: true);
    await _persistSession();
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

    // Stop background event producers so submit is not blocked by new proctoring events.
    _disposeRuntimeServices();

    await _clearOutboxFromOtherAttempts(attempt.id);
    await flushOutbox(
      onlyTypes: <OutboxItemType>{OutboxItemType.answer},
      onlyAttemptId: attempt.id,
    );
    final hasPendingAnswers = await _hasPendingAnswersForAttempt(attempt.id);
    if (hasPendingAnswers) {
      if (state.hasActiveAttempt && state.remainingSeconds > 0) {
        _startRuntimeServices();
      }
      state = state.copyWith(
        submitState: SubmitState.failed,
        isLoading: false,
        errorMessage:
            'Sebagian jawaban belum tersinkron. Periksa koneksi lalu coba kumpulkan lagi.',
      );
      await _persistSession();
      return;
    }

    await _queue.enqueueSubmit(attemptId: attempt.id);
    await _refreshQueueSnapshot();
    await flushOutbox(
      onlyTypes: <OutboxItemType>{OutboxItemType.submit},
      onlyAttemptId: attempt.id,
    );

    if (state.submitState != SubmitState.success) {
      if (state.hasActiveAttempt && state.remainingSeconds > 0) {
        _startRuntimeServices();
      }
      state = state.copyWith(
        submitState: SubmitState.failed,
        isLoading: false,
        errorMessage: state.errorMessage ?? 'Pengumpulan ujian belum berhasil.',
      );
      await _persistSession();
    }
  }

  Future<void> flushOutbox({
    Set<OutboxItemType>? onlyTypes,
    String? onlyAttemptId,
  }) async {
    if (_isFlushing) {
      return;
    }
    _isFlushing = true;
    try {
      final dueItems = await _queue.getDueItems();
      final targetItems = dueItems.where((item) {
        if (onlyTypes != null && !onlyTypes.contains(item.type)) {
          return false;
        }
        if (onlyAttemptId != null &&
            item.payload['attemptId'] != onlyAttemptId) {
          return false;
        }
        return true;
      }).toList();
      if (targetItems.isEmpty) {
        await _refreshQueueSnapshot();
        return;
      }

      for (final item in targetItems) {
        try {
          await _handleOutboxItem(item);
          await _queue.markSuccess(item.id);
          state = state.copyWith(
            connectionState: ConnectionStatus.online,
            syncStatus: SyncStatus.synced,
            clearErrorMessage: true,
          );
        } on ApiError catch (error) {
          if (!_isRetryableApiError(error)) {
            await _queue.markSuccess(item.id);
            if (_shouldResetSessionFromApiError(error)) {
              await clearSession();
              state = state.copyWith(
                submitState: SubmitState.failed,
                isLoading: false,
                errorMessage:
                    'Sesi ujian sudah berakhir. Silakan login kembali lalu lanjutkan.',
              );
              break;
            }

            final isSubmit = item.type == OutboxItemType.submit;
            state = state.copyWith(
              connectionState: ConnectionStatus.online,
              syncStatus: SyncStatus.pending,
              submitState: isSubmit ? SubmitState.failed : state.submitState,
              isLoading: isSubmit ? false : state.isLoading,
              errorMessage: error.message,
            );
            if (isSubmit) {
              break;
            }
            continue;
          }

          if (_shouldResetSessionFromApiError(error)) {
            await clearSession();
            state = state.copyWith(
              submitState: SubmitState.failed,
              isLoading: false,
              errorMessage:
                  'Sesi ujian sudah berakhir. Silakan mulai ujian baru.',
            );
            break;
          }

          final action = await _queue.markFailure(item.id);
          final dropped = action == OutboxFailureAction.dropped;
          state = state.copyWith(
            connectionState: _resolveConnectionStatus(error),
            syncStatus: dropped
                ? SyncStatus.pending
                : _syncStatusFromFailureAction(action),
            submitState: dropped && item.type == OutboxItemType.submit
                ? SubmitState.failed
                : state.submitState,
            errorMessage:
                dropped ? _buildDroppedQueueMessage(item) : error.message,
          );
        } catch (_) {
          final action = await _queue.markFailure(item.id);
          final dropped = action == OutboxFailureAction.dropped;
          state = state.copyWith(
            connectionState: ConnectionStatus.offline,
            syncStatus: dropped
                ? SyncStatus.pending
                : _syncStatusFromFailureAction(action),
            submitState: dropped && item.type == OutboxItemType.submit
                ? SubmitState.failed
                : state.submitState,
            errorMessage: dropped
                ? _buildDroppedQueueMessage(item)
                : 'Koneksi sedang bermasalah. Sistem akan coba lagi.',
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
          remainingSeconds: 0,
          clearServerDeadline: true,
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

    final now = _resolveNowServerUtc();
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
    if (state.attempt != null) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        state = ExamSessionState.fromJson(decoded);
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

  SyncStatus _syncStatusFromFailureAction(OutboxFailureAction action) {
    if (action == OutboxFailureAction.missing) {
      return SyncStatus.pending;
    }
    return SyncStatus.retrying;
  }

  bool _isRetryableApiError(ApiError error) {
    final statusCode = error.statusCode;
    if (statusCode == null) {
      return true;
    }
    return statusCode == 429 || statusCode >= 500;
  }

  bool _shouldResetSessionFromApiError(ApiError error) {
    final statusCode = error.statusCode;
    if (statusCode == 401) {
      return true;
    }
    if (statusCode != 400 && statusCode != 403) {
      return false;
    }

    final message = error.message.toLowerCase();
    if (statusCode == 403 &&
        (message.contains('token') ||
            message.contains('unauthorized') ||
            message.contains('jwt') ||
            message.contains('invalid') ||
            message.contains('expired') ||
            message.contains('akses ditolak'))) {
      return true;
    }

    return message.contains('sesi ujian sudah tidak aktif') ||
        message.contains('waktu sesi ujian sudah habis') ||
        message.contains('ujian tidak tersedia pada waktu ini') ||
        message.contains('ujian belum dipublikasikan') ||
        message.contains('ujian sudah ditutup');
  }

  String _buildDroppedQueueMessage(OutboxItem item) {
    switch (item.type) {
      case OutboxItemType.answer:
        return 'Simpan otomatis gagal setelah beberapa kali percobaan. Jawab ulang soal ini untuk mengirim lagi.';
      case OutboxItemType.proctoring:
        return 'Sebagian data pengawasan gagal dikirim setelah batas percobaan.';
      case OutboxItemType.submit:
        return 'Pengumpulan gagal setelah beberapa kali percobaan. Silakan coba kirim lagi.';
    }
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
          warning: 'Aplikasi berpindah ke latar belakang terdeteksi.',
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
          warning: value >= 70 ? 'Suara sekitar terlalu bising.' : null,
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
      if (state.hasActiveAttempt &&
          state.remainingSeconds <= 0 &&
          state.submitState == SubmitState.idle) {
        state = state.copyWith(
          warningMessage: 'Waktu habis. Jawaban sedang dikumpulkan otomatis.',
        );
        await submitAttempt();
      }
    });
  }

  Future<bool> _hasPendingAnswersForAttempt(String attemptId) async {
    final rows = await _queue.getItems();
    for (final row in rows) {
      if (row.type != OutboxItemType.answer) {
        continue;
      }
      if (row.payload['attemptId'] == attemptId) {
        return true;
      }
    }
    return false;
  }

  Future<void> _clearOutboxFromOtherAttempts(String attemptId) async {
    final rows = await _queue.getItems();
    for (final row in rows) {
      final rowAttemptId = row.payload['attemptId'];
      if (rowAttemptId == null || rowAttemptId == attemptId) {
        continue;
      }
      await _queue.markSuccess(row.id);
    }
    await _refreshQueueSnapshot();
  }

  void _recalculateTimer() {
    final serverDeadlineEpochMs = state.serverDeadlineEpochMs;
    if (serverDeadlineEpochMs != null) {
      final nowMs = _resolveNowServerUtc().millisecondsSinceEpoch;
      final seconds = max(0, ((serverDeadlineEpochMs - nowMs) / 1000).floor());
      state = state.copyWith(remainingSeconds: seconds);
      return;
    }

    final attempt = state.attempt;
    final subject = state.subject;
    if (attempt == null || subject == null) {
      state = state.copyWith(remainingSeconds: 0);
      return;
    }

    final startedAt = attempt.startTime.toUtc();
    final byDuration =
        startedAt.add(Duration(minutes: subject.durationMinutes));
    final closeAt = subject.closeAt?.toUtc();
    final hardDeadline =
        closeAt != null && closeAt.isBefore(byDuration) ? closeAt : byDuration;
    final nowServer = _resolveNowServerUtc();
    final seconds = max(
      0,
      hardDeadline.difference(nowServer).inSeconds,
    );
    state = state.copyWith(remainingSeconds: seconds);
  }

  DateTime _resolveNowServerUtc() {
    final localUtc = DateTime.now().toUtc();
    return localUtc.add(Duration(milliseconds: state.serverOffsetMs));
  }

  int _serverOffsetFrom(DateTime? serverNow) {
    if (serverNow == null) {
      return 0;
    }
    final normalizedServerNow = serverNow.toUtc();
    final localUtc = DateTime.now().toUtc();
    return normalizedServerNow.difference(localUtc).inMilliseconds;
  }

  int? _resolveServerDeadlineEpochMs({
    required DateTime? serverNow,
    required int? remainingSeconds,
  }) {
    if (serverNow == null || remainingSeconds == null) {
      return null;
    }

    final safeRemainingSeconds = max(0, remainingSeconds);
    return serverNow.toUtc().millisecondsSinceEpoch +
        safeRemainingSeconds * 1000;
  }
}
