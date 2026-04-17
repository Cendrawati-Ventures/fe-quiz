import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_button.dart';
import '../../../shared/components/app_card.dart';
import '../model/exam_models.dart';
import '../state/exam_state.dart';

class ExamDetailStartScreen extends ConsumerStatefulWidget {
  const ExamDetailStartScreen({
    required this.examId,
    super.key,
  });

  final String examId;

  @override
  ConsumerState<ExamDetailStartScreen> createState() =>
      _ExamDetailStartScreenState();
}

class _ExamDetailStartScreenState extends ConsumerState<ExamDetailStartScreen> {
  String? _selectedSubjectId;

  @override
  Widget build(BuildContext context) {
    final examsAsync = ref.watch(examListProvider);
    final subjectsAsync = ref.watch(subjectListProvider);
    final sessionState = ref.watch(examSessionProvider);
    final sessionNotifier = ref.read(examSessionProvider.notifier);
    final subjects = subjectsAsync.maybeWhen(
      data: (items) => items,
      orElse: () => <ApiSubject>[],
    );

    final exam = examsAsync.maybeWhen(
      data: (items) {
        for (final item in items) {
          if (item.id == widget.examId) {
            return item;
          }
        }
        return null;
      },
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Ujian')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ListView(
          children: <Widget>[
            if (exam == null)
              const AppCard(
                title: 'Ujian tidak ditemukan',
                subtitle: 'Silakan kembali ke daftar ujian.',
              )
            else
              AppCard(
                title: exam.title,
                subtitle:
                    'Mulai: ${exam.startTime.toLocal()}\nSelesai: ${exam.endTime.toLocal()}',
              ),
            const SizedBox(height: AppSpacing.md),
            subjectsAsync.when(
              data: (subjects) {
                if (subjects.isEmpty) {
                  return const AppCard(
                    title: 'Subject kosong',
                    subtitle: 'Belum ada subject yang bisa dipilih.',
                  );
                }

                _selectedSubjectId ??= subjects.first.id;
                return AppCard(
                  title: 'Pilih Subject',
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSubjectId,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    items: subjects
                        .map(
                          (subject) => DropdownMenuItem<String>(
                            value: subject.id,
                            child: Text(
                              '${subject.name} (${subject.durationMinutes} menit)',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _selectedSubjectId = value;
                    }),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => AppCard(
                title: 'Gagal memuat subject',
                subtitle: error.toString(),
              ),
            ),
            if (sessionState.errorMessage != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                sessionState.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Start Attempt',
              loading: sessionState.isLoading,
              disabled: exam == null ||
                  _selectedSubjectId == null ||
                  sessionState.isLoading,
              onPressed: () async {
                final selectedSubjectId = _selectedSubjectId;
                if (exam == null || selectedSubjectId == null) {
                  return;
                }

                ApiSubject? selectedSubject;
                for (final subject in subjects) {
                  if (subject.id == selectedSubjectId) {
                    selectedSubject = subject;
                    break;
                  }
                }
                if (selectedSubject == null) {
                  return;
                }

                await sessionNotifier.startAttempt(
                  exam: exam,
                  subject: selectedSubject,
                );
                if (!context.mounted) {
                  return;
                }

                final latestSession = ref.read(examSessionProvider);
                if (latestSession.hasActiveAttempt) {
                  context.go('/exam/session');
                  return;
                }

                if (latestSession.errorMessage != null) {
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(latestSession.errorMessage!)),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
