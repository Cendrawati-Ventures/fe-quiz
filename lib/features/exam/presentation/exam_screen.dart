import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../model/exam_models.dart';
import '../state/exam_state.dart';

class ExamScreen extends ConsumerStatefulWidget {
  const ExamScreen({super.key});

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> {
  bool _isSubmitFailureDialogVisible = false;
  BuildContext? _submitFailureDialogContext;

  @override
  void initState() {
    super.initState();
    _enableSecureFlag();
  }

  @override
  void dispose() {
    _dismissSubmitFailureDialog();
    _disableSecureFlag();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ExamSessionState>(examSessionProvider, (previous, next) {
      if (previous?.submitState != SubmitState.success &&
          next.submitState == SubmitState.success &&
          mounted) {
        _dismissSubmitFailureDialog();
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

    if (!state.hasActiveAttempt || question == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exam Session')),
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Keluar dari exam?'),
              content: const Text(
                'Progress tetap tersimpan, tapi event proctoring akan tercatat.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Batal'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Keluar'),
                ),
              ],
            );
          },
        );

        if (confirmed == true && context.mounted) {
          context.go('/exam');
        }
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => notifier.onUserInteraction(),
        child: Scaffold(
          appBar: AppBar(
            title: Text(state.exam?.title ?? 'Exam'),
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
              label: currentIndex == 0 ? 'Previous' : 'Previous',
              onPressed: currentIndex == 0 ? null : notifier.previousQuestion,
              disabled: currentIndex == 0,
              variant: AppButtonVariant.secondary,
            ),
            primaryAction: Row(
              children: <Widget>[
                Expanded(
                  child: BottomActionBarButton(
                    label:
                        currentIndex == totalQuestions - 1 ? 'Submit' : 'Next',
                    onPressed: currentIndex == totalQuestions - 1
                        ? () async {
                            final shouldSubmit = await _confirmSubmit(
                              context,
                              state.unansweredCount,
                            );
                            if (!shouldSubmit) {
                              return;
                            }
                            await notifier.submitAttempt();
                          }
                        : notifier.nextQuestion,
                    loading: state.submitState == SubmitState.submitting,
                    disabled: state.submitState == SubmitState.submitting,
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
                title: const Text('Submit Gagal'),
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
                        : const Text('Retry Submit'),
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

  Future<void> _enableSecureFlag() async {
    await ScreenSecurity.enableSecureFlag();
  }

  Future<void> _disableSecureFlag() async {
    await ScreenSecurity.disableSecureFlag();
  }

  Future<bool> _confirmSubmit(BuildContext context, int unansweredCount) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Konfirmasi Submit'),
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
              child: const Text('Submit'),
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
          result.add(_OptionView(value: value, label: label));
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
        result.add(_OptionView(value: key, label: label));
      });
      return result;
    }

    return result;
  }
}

class _OptionView {
  const _OptionView({required this.value, required this.label});

  final String value;
  final String label;
}
