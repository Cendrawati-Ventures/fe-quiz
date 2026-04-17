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
  @override
  void initState() {
    super.initState();
    _enableSecureFlag();
  }

  @override
  void dispose() {
    _disableSecureFlag();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ExamSessionState>(examSessionProvider, (previous, next) {
      if (previous?.submitState != SubmitState.success &&
          next.submitState == SubmitState.success &&
          mounted) {
        context.go('/result');
        return;
      }

      if (next.submitState == SubmitState.failed &&
          next.errorMessage != null &&
          next.errorMessage!.isNotEmpty &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
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
    final options = _normalizeOptions(question.options);
    final isMulti = question.type == QuestionType.multi ||
        question.type == QuestionType.group;
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
                  child: ListView.builder(
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
