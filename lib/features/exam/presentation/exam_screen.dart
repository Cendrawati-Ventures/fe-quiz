import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../app/theme/spacing.dart';
import '../../../core/device/screen_security.dart';
import '../../../shared/components/app_button.dart';
import '../../../shared/components/bottom_action_bar.dart';
import '../../../shared/components/connection_chip.dart';
import '../../../shared/components/option_item.dart';
import '../../../shared/components/progress_bar.dart';
import '../../../shared/components/question_card.dart';
import '../../../shared/components/timer_widget.dart';
import '../../../shared/components/warning_banner.dart';
import '../../auth/model/auth_user.dart';
import '../../auth/state/auth_provider.dart';
import '../../exam_monitoring/state/student_monitoring_state.dart';
import '../model/exam_models.dart';
import '../state/exam_state.dart';

class ExamScreen extends ConsumerStatefulWidget {
  const ExamScreen({super.key});

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> {
  // ponytail: music is disabled; restore its asset in pubspec.yaml before enabling it.
  static const bool _backgroundMusicEnabled = false;
  static const String _backgroundMusicAsset = 'audio/default-music.wav';
  static const double _backgroundMusicVolume = 0.28;
  static const Duration _audioChunkDuration = Duration(seconds: 30);
  static const String _audioChunkMimeType = 'audio/mp4';
  static const String _audioChunkFileExtension = 'm4a';

  bool _isSubmitFailureDialogVisible = false;
  BuildContext? _submitFailureDialogContext;
  bool _isExitBlockedDialogVisible = false;
  AudioPlayer? _backgroundMusicPlayer;
  String? _playingAttemptId;
  bool _isBackgroundMusicSyncing = false;
  AudioRecorder? _audioRecorder;
  Timer? _audioChunkTimer;
  bool _isAudioCaptureTransitioning = false;
  String? _audioCaptureAttemptId;
  DateTime? _audioChunkStartedAt;
  int _nextAudioChunkIndex = 0;

  @override
  void initState() {
    super.initState();
    _enableSecureFlag();
  }

  @override
  void dispose() {
    _dismissSubmitFailureDialog();
    unawaited(_stopAudioCapture(uploadFinalChunk: true));
    unawaited(_disposeAudioCapture());
    _disposeBackgroundMusic();
    _disableSecureFlag();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monitoringSession = ref.read(studentMonitoringSessionProvider);
    final authUser = ref.watch(authProvider.select((value) => value.user));
    ref.listen<ExamSessionState>(examSessionProvider, (previous, next) {
      _syncBackgroundMusic(next);
      _syncAudioCapture(next);
      _syncStudentMonitoring(next, user: authUser);

      if (previous?.submitState != SubmitState.success &&
          next.submitState == SubmitState.success &&
          mounted) {
        _dismissSubmitFailureDialog();
        unawaited(_stopAudioCapture(uploadFinalChunk: true));
        _stopBackgroundMusic();
        unawaited(monitoringSession.stop(markFinished: true));
        ref.invalidate(myResultsProvider);
        context.go('/result');
        return;
      }

      final failedNow = previous?.submitState != SubmitState.failed &&
          next.submitState == SubmitState.failed;
      if (failedNow &&
          next.hasActiveAttempt &&
          next.errorMessage != null &&
          next.errorMessage!.isNotEmpty &&
          mounted) {
        _showSubmitFailureDialog(next.errorMessage!);
      }
    });

    final state = ref.watch(examSessionProvider);
    final notifier = ref.read(examSessionProvider.notifier);
    final question = state.currentQuestion;
    final totalQuestions = state.questions.length;
    final currentIndex = state.currentQuestionIndex;
    _syncBackgroundMusic(state);
    _syncAudioCapture(state);
    _syncStudentMonitoring(state, user: authUser);

    if (state.hasActiveAttempt && !state.monitoringPrecheckConfirmed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.go('/exam/session/precheck');
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!state.hasActiveAttempt &&
        state.submitState == SubmitState.success &&
        state.latestResult != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.go('/result');
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!state.hasActiveAttempt || question == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sesi Ujian')),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('Tidak ada sesi ujian aktif.'),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Kembali ke Daftar Ujian',
                onPressed: () => context.go('/exam'),
              ),
            ],
          ),
        ),
      );
    }

    final answer = state.answersByQuestionId[question.id];
    final isGroupQuestion = question.type == QuestionType.group;
    final groupSubQuestions = isGroupQuestion
        ? extractGroupSubQuestions(question.options)
        : const <GroupSubQuestion>[];
    final groupParentText =
        isGroupQuestion ? extractGroupParentText(question.options) : null;
    final groupAnswerMap =
        isGroupQuestion ? normalizeGroupAnswerMap(answer) : <String, dynamic>{};
    final options = _normalizeOptions(question.options);
    final isMulti = question.type == QuestionType.multi ||
        (isGroupQuestion && groupSubQuestions.isEmpty);
    final progress =
        totalQuestions == 0 ? 0.0 : (currentIndex + 1) / totalQuestions;
    final isLastQuestion = currentIndex == totalQuestions - 1;
    final unansweredCount = state.unansweredCount;
    final canSubmitAllAnswers = unansweredCount == 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) async {
        await notifier.reportProctoringSignal(
          type: ProctoringEventType.tabSwitch,
          value: 100,
          warning: 'Menekan tombol kembali saat ujian sedang berlangsung.',
        );
        await _showExitBlockedDialog();
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => notifier.onUserInteraction(),
        child: Scaffold(
          appBar: AppBar(
            title: Text(state.subject?.name ?? state.exam?.title ?? 'Ujian'),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Center(
                  child: TimerWidget(
                    remainingSeconds: state.remainingSeconds,
                    isWarning: state.remainingSeconds <= 300,
                  ),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ConnectionChip(
                  isOnline: state.connectionState != ConnectionStatus.offline,
                  syncStatus: state.syncStatus.name,
                ),
                const SizedBox(height: AppSpacing.sm),
                _CountdownPanel(remainingSeconds: state.remainingSeconds),
                if (state.warningMessage != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  WarningBanner(
                    type: WarningBannerType.warning,
                    message: state.warningMessage!,
                    isVisible: true,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                ProgressBar(
                  current: currentIndex + 1,
                  total: totalQuestions,
                  value: progress,
                ),
                const SizedBox(height: AppSpacing.md),
                QuestionCard(
                  question: question,
                  questionIndex: currentIndex,
                  totalQuestion: totalQuestions,
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: isGroupQuestion && groupSubQuestions.isNotEmpty
                      ? _buildGroupQuestionBody(
                          questionId: question.id,
                          parentText: groupParentText,
                          subQuestions: groupSubQuestions,
                          groupAnswer: groupAnswerMap,
                        )
                      : ListView.builder(
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options[index];
                            final selected = _isOptionSelected(
                              answer: answer,
                              optionValue: option.value,
                              isMulti: isMulti,
                            );
                            return OptionItem(
                              option: option.label,
                              imageData: option.imageData,
                              selected: selected,
                              multiSelect: isMulti,
                              onTap: () {
                                final nextAnswer = _nextAnswerValue(
                                  previousAnswer: answer,
                                  optionValue: option.value,
                                  isMulti: isMulti,
                                );
                                notifier.answerQuestion(
                                  questionId: question.id,
                                  answer: nextAnswer,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: BottomActionBar(
            secondaryAction: BottomActionBarButton(
              label: 'Sebelumnya',
              onPressed: currentIndex == 0 ? null : notifier.previousQuestion,
              disabled: currentIndex == 0,
              variant: AppButtonVariant.secondary,
            ),
            primaryAction: Row(
              children: <Widget>[
                Expanded(
                  child: BottomActionBarButton(
                    label: isLastQuestion
                        ? (canSubmitAllAnswers
                            ? 'Kumpulkan'
                            : 'Jawab $unansweredCount Lagi')
                        : 'Berikutnya',
                    onPressed: isLastQuestion
                        ? () async {
                            if (!canSubmitAllAnswers) {
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Masih ada $unansweredCount soal yang belum dijawab.',
                                  ),
                                ),
                              );
                              return;
                            }
                            final shouldSubmit = await _confirmSubmit(
                              context,
                              unansweredCount,
                            );
                            if (!shouldSubmit) {
                              return;
                            }
                            await notifier.submitAttempt();
                          }
                        : notifier.nextQuestion,
                    loading: state.submitState == SubmitState.submitting,
                    disabled: state.submitState == SubmitState.submitting ||
                        (isLastQuestion && !canSubmitAllAnswers),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupQuestionBody({
    required String questionId,
    required String? parentText,
    required List<GroupSubQuestion> subQuestions,
    required Map<String, dynamic> groupAnswer,
  }) {
    final notifier = ref.read(examSessionProvider.notifier);

    return ListView.builder(
      itemCount: subQuestions.length + (parentText == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (parentText != null && index == 0) {
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(parentText),
            ),
          );
        }

        final safeIndex = parentText == null ? index : index - 1;
        final subQuestion = subQuestions[safeIndex];
        final subOptions = _normalizeOptions(subQuestion.options);
        final isMulti = subQuestion.type == QuestionType.multi;
        final subAnswer = groupAnswer[subQuestion.id];

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${safeIndex + 1}. ${subQuestion.text}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (subOptions.isEmpty)
                  const Text('Opsi tidak tersedia untuk sub-soal ini.'),
                ...subOptions.map((option) {
                  final selected = _isOptionSelected(
                    answer: subAnswer,
                    optionValue: option.value,
                    isMulti: isMulti,
                  );
                  return OptionItem(
                    option: option.label,
                    imageData: option.imageData,
                    selected: selected,
                    multiSelect: isMulti,
                    onTap: () {
                      final latestSession = ref.read(examSessionProvider);
                      final latestGroupAnswer = normalizeGroupAnswerMap(
                        latestSession.answersByQuestionId[questionId],
                      );
                      final latestSubAnswer = latestGroupAnswer[subQuestion.id];
                      final nextSubAnswer = _nextAnswerValue(
                        previousAnswer: latestSubAnswer,
                        optionValue: option.value,
                        isMulti: isMulti,
                      );
                      final nextGroupAnswer =
                          Map<String, dynamic>.from(latestGroupAnswer);
                      if (_isAnswerEmpty(nextSubAnswer)) {
                        nextGroupAnswer.remove(subQuestion.id);
                      } else {
                        nextGroupAnswer[subQuestion.id] = nextSubAnswer;
                      }
                      notifier.answerQuestion(
                        questionId: questionId,
                        answer: nextGroupAnswer,
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSubmitFailureDialog(String message) async {
    if (_isSubmitFailureDialogVisible || !mounted) {
      return;
    }
    _isSubmitFailureDialogVisible = true;
    _submitFailureDialogContext = null;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _submitFailureDialogContext = dialogContext;
        return PopScope(
          canPop: false,
          child: Consumer(
            builder: (context, ref, _) {
              final session = ref.watch(examSessionProvider);
              final submitting = session.submitState == SubmitState.submitting;
              final errorText = session.errorMessage ?? message;

              return AlertDialog(
                title: const Text('Pengumpulan Gagal'),
                content: Text(errorText),
                actions: <Widget>[
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            await ref
                                .read(examSessionProvider.notifier)
                                .submitAttempt();
                          },
                    child: submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Coba Kirim Lagi'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    _isSubmitFailureDialogVisible = false;
    _submitFailureDialogContext = null;
  }

  void _dismissSubmitFailureDialog() {
    if (!_isSubmitFailureDialogVisible) {
      return;
    }
    final dialogContext = _submitFailureDialogContext;
    if (dialogContext == null || !dialogContext.mounted) {
      return;
    }
    final navigator = Navigator.of(dialogContext, rootNavigator: true);
    if (!navigator.canPop()) {
      return;
    }
    navigator.pop();
    _isSubmitFailureDialogVisible = false;
    _submitFailureDialogContext = null;
  }

  Future<void> _showExitBlockedDialog() async {
    if (_isExitBlockedDialogVisible || !mounted) {
      return;
    }
    _isExitBlockedDialogVisible = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Ujian Sedang Berlangsung'),
            content: const Text(
              'Tombol kembali dinonaktifkan selama ujian berjalan. Silakan lanjutkan mengerjakan ujian.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Lanjut Kerjakan'),
              ),
            ],
          ),
        );
      },
    );

    _isExitBlockedDialogVisible = false;
  }

  Future<void> _enableSecureFlag() async {
    await ScreenSecurity.enableSecureFlag();
  }

  Future<void> _disableSecureFlag() async {
    await ScreenSecurity.disableSecureFlag();
  }

  void _syncStudentMonitoring(
    ExamSessionState state, {
    AuthUser? user,
  }) {
    final monitoringSession = ref.read(studentMonitoringSessionProvider);
    if (!state.hasActiveAttempt) {
      unawaited(monitoringSession.stop(markFinished: false));
      return;
    }

    if (state.submitState == SubmitState.success) {
      return;
    }

    final config = resolveStudentMonitoringConfig(
      user: user,
      sessionState: state,
    );
    if (config == null) {
      return;
    }

    unawaited(monitoringSession.ensureStarted(config));
  }

  void _syncAudioCapture(ExamSessionState state) {
    final attempt = state.attempt;
    final shouldCapture = state.hasActiveAttempt &&
        attempt != null &&
        state.submitState != SubmitState.submitting;

    if (!shouldCapture) {
      unawaited(_stopAudioCapture(uploadFinalChunk: true));
      return;
    }

    if (_audioCaptureAttemptId == attempt.id) {
      return;
    }

    unawaited(_restartAudioCaptureForAttempt(attempt.id));
  }

  Future<void> _restartAudioCaptureForAttempt(String attemptId) async {
    if (_isAudioCaptureTransitioning) {
      return;
    }

    _isAudioCaptureTransitioning = true;
    try {
      await _stopAudioCapture(uploadFinalChunk: true);
      _audioCaptureAttemptId = attemptId;
      _audioChunkStartedAt = null;
      _nextAudioChunkIndex = 0;
      await _startAudioChunkRecording();
    } finally {
      _isAudioCaptureTransitioning = false;
    }
  }

  Future<void> _startAudioChunkRecording() async {
    final attemptId = _audioCaptureAttemptId;
    if (attemptId == null) {
      return;
    }

    final recorder = _audioRecorder ?? AudioRecorder();
    _audioRecorder = recorder;

    try {
      final hasPermission = await recorder.hasPermission();
      if (!hasPermission) {
        return;
      }

      if (_audioCaptureAttemptId != attemptId) {
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}${Platform.pathSeparator}attempt_${attemptId}_${DateTime.now().millisecondsSinceEpoch}.$_audioChunkFileExtension';

      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
          androidConfig: AndroidRecordConfig(
            audioSource: AndroidAudioSource.voiceRecognition,
            audioManagerMode: AudioManagerMode.modeInCommunication,
            muteAudio: true,
          ),
        ),
        path: filePath,
      );

      _audioChunkStartedAt = DateTime.now().toUtc();
      _audioChunkTimer?.cancel();
      _audioChunkTimer = Timer(_audioChunkDuration, () {
        unawaited(_rotateAudioChunk());
      });
    } catch (_) {
      _audioChunkTimer?.cancel();
      _audioChunkTimer = null;
      _audioChunkStartedAt = null;
    }
  }

  Future<void> _rotateAudioChunk() async {
    final recorder = _audioRecorder;
    final attemptId = _audioCaptureAttemptId;
    if (recorder == null || attemptId == null) {
      return;
    }

    try {
      final isRecording = await recorder.isRecording();
      if (!isRecording) {
        return;
      }

      final startedAt = _audioChunkStartedAt ?? DateTime.now().toUtc();
      final filePath = await recorder.stop();
      final endedAt = DateTime.now().toUtc();
      _audioChunkStartedAt = null;

      if (filePath != null && filePath.trim().isNotEmpty) {
        final chunkIndex = _nextAudioChunkIndex;
        _nextAudioChunkIndex += 1;
        unawaited(
          _uploadAudioChunk(
            attemptId: attemptId,
            chunkIndex: chunkIndex,
            startedAt: startedAt,
            endedAt: endedAt,
            filePath: filePath,
          ),
        );
      }
    } catch (_) {
      _audioChunkStartedAt = null;
    }

    if (_audioCaptureAttemptId == attemptId) {
      await _startAudioChunkRecording();
    }
  }

  Future<void> _stopAudioCapture({required bool uploadFinalChunk}) async {
    _audioChunkTimer?.cancel();
    _audioChunkTimer = null;

    final recorder = _audioRecorder;
    final attemptId = _audioCaptureAttemptId;
    final startedAt = _audioChunkStartedAt;

    _audioCaptureAttemptId = null;
    _audioChunkStartedAt = null;

    if (recorder == null || attemptId == null) {
      return;
    }

    try {
      final isRecording = await recorder.isRecording();
      if (!isRecording) {
        return;
      }

      final filePath = await recorder.stop();
      if (!uploadFinalChunk || filePath == null || filePath.trim().isEmpty) {
        return;
      }

      final endedAt = DateTime.now().toUtc();
      final chunkIndex = _nextAudioChunkIndex;
      _nextAudioChunkIndex += 1;

      await _uploadAudioChunk(
        attemptId: attemptId,
        chunkIndex: chunkIndex,
        startedAt: startedAt ?? endedAt,
        endedAt: endedAt,
        filePath: filePath,
      );
    } catch (_) {}
  }

  Future<void> _uploadAudioChunk({
    required String attemptId,
    required int chunkIndex,
    required DateTime startedAt,
    required DateTime endedAt,
    required String filePath,
  }) async {
    final audioFile = File(filePath);
    try {
      if (!await audioFile.exists()) {
        return;
      }

      await ref.read(examServiceProvider).uploadProctoringAudioChunk(
            attemptId: attemptId,
            chunkIndex: chunkIndex,
            startedAt: startedAt,
            endedAt: endedAt,
            filePath: filePath,
            mimeType: _audioChunkMimeType,
          );
    } catch (_) {
      // Rekaman audio bersifat best effort dan tidak boleh memblokir ujian.
    } finally {
      try {
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      } catch (_) {}
    }
  }

  Future<void> _disposeAudioCapture() async {
    _audioChunkTimer?.cancel();
    _audioChunkTimer = null;
    _audioCaptureAttemptId = null;
    _audioChunkStartedAt = null;

    final recorder = _audioRecorder;
    _audioRecorder = null;
    if (recorder == null) {
      return;
    }

    try {
      await recorder.dispose();
    } catch (_) {}
  }

  void _syncBackgroundMusic(ExamSessionState state) {
    if (!_backgroundMusicEnabled) {
      _stopBackgroundMusic();
      return;
    }

    final attempt = state.attempt;
    if (!state.hasActiveAttempt || attempt == null) {
      _stopBackgroundMusic();
      return;
    }

    if (_playingAttemptId == attempt.id) {
      return;
    }

    _startBackgroundMusic(attempt.id);
  }

  Future<void> _startBackgroundMusic(String attemptId) async {
    if (_isBackgroundMusicSyncing) {
      return;
    }

    _isBackgroundMusicSyncing = true;
    try {
      final player = _backgroundMusicPlayer ?? AudioPlayer();
      _backgroundMusicPlayer = player;

      await player.stop();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_backgroundMusicVolume);
      await player.play(AssetSource(_backgroundMusicAsset));

      _playingAttemptId = attemptId;
    } catch (_) {
      _playingAttemptId = null;
    } finally {
      _isBackgroundMusicSyncing = false;
    }
  }

  Future<void> _stopBackgroundMusic() async {
    final player = _backgroundMusicPlayer;
    _playingAttemptId = null;

    if (player == null) {
      return;
    }

    try {
      await player.stop();
    } catch (_) {}
  }

  Future<void> _disposeBackgroundMusic() async {
    final player = _backgroundMusicPlayer;
    _backgroundMusicPlayer = null;
    _playingAttemptId = null;

    if (player == null) {
      return;
    }

    try {
      await player.stop();
    } catch (_) {}

    try {
      await player.dispose();
    } catch (_) {}
  }

  Future<bool> _confirmSubmit(BuildContext context, int unansweredCount) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Konfirmasi Pengumpulan'),
          content: Text(
            'Apakah kamu yakin ingin mengumpulkan ujian?\n'
            'Jawaban belum lengkap: $unansweredCount soal.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Kumpulkan'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  bool _isOptionSelected({
    required Object? answer,
    required String optionValue,
    required bool isMulti,
  }) {
    if (!isMulti) {
      return answer == optionValue;
    }
    if (answer is List<dynamic>) {
      return answer.contains(optionValue);
    }
    return false;
  }

  Object _nextAnswerValue({
    required Object? previousAnswer,
    required String optionValue,
    required bool isMulti,
  }) {
    if (!isMulti) {
      return optionValue;
    }

    final values = <String>[
      ...((previousAnswer is List<dynamic>)
          ? previousAnswer.whereType<String>()
          : <String>[]),
    ];
    if (values.contains(optionValue)) {
      values.remove(optionValue);
    } else {
      values.add(optionValue);
    }
    return values;
  }

  bool _isAnswerEmpty(Object? value) {
    if (value == null) {
      return true;
    }
    if (value is String) {
      return value.trim().isEmpty;
    }
    if (value is List<dynamic>) {
      return value.isEmpty;
    }
    if (value is Map<String, dynamic>) {
      return value.isEmpty;
    }
    return false;
  }

  List<_OptionView> _normalizeOptions(Object? options) {
    final result = <_OptionView>[];
    if (options is List<dynamic>) {
      for (var i = 0; i < options.length; i++) {
        final entry = options[i];
        if (entry is Map<String, dynamic>) {
          final value = (entry['value'] ?? entry['id'] ?? '$i').toString();
          final label = (entry['label'] ?? entry['text'] ?? value).toString();
          result.add(
            _OptionView(
              value: value,
              label: label,
              imageData: entry['imageData'] as String?,
            ),
          );
        } else {
          final value = entry.toString();
          result.add(_OptionView(value: value, label: value));
        }
      }
      return result;
    }

    if (options is Map<String, dynamic>) {
      options.forEach((key, value) {
        final label = value is Map<String, dynamic>
            ? (value['label'] ?? value['text'] ?? key).toString()
            : value.toString();
        result.add(
          _OptionView(
            value: key,
            label: label,
            imageData: value is Map<String, dynamic>
                ? value['imageData'] as String?
                : null,
          ),
        );
      });
      return result;
    }

    return result;
  }
}

class _OptionView {
  const _OptionView({
    required this.value,
    required this.label,
    this.imageData,
  });

  final String value;
  final String label;
  final String? imageData;
}

class _CountdownPanel extends StatelessWidget {
  const _CountdownPanel({required this.remainingSeconds});

  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    final isWarning = remainingSeconds <= 300;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isWarning
            ? Theme.of(context).colorScheme.error.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        border: Border.all(
          color: isWarning
              ? Theme.of(context).colorScheme.error.withValues(alpha: 0.35)
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.timer_rounded,
            color: isWarning
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Sisa Waktu:',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(width: AppSpacing.xs),
          TimerWidget(
            remainingSeconds: remainingSeconds,
            isWarning: isWarning,
          ),
        ],
      ),
    );
  }
}
