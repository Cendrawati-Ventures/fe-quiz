import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_button.dart';
import '../../../shared/components/app_card.dart';
import '../../../shared/components/app_snackbar.dart';
import '../model/exam_models.dart';
import '../state/admin_question_state.dart';
import '../state/exam_state.dart';
import 'widgets/admin_layout.dart';
import 'widgets/question_form_fields.dart';

class AdminQuestionManagementScreen extends ConsumerStatefulWidget {
  const AdminQuestionManagementScreen({
    super.key,
    this.initialSubjectId,
  });

  final String? initialSubjectId;

  @override
  ConsumerState<AdminQuestionManagementScreen> createState() =>
      _AdminQuestionManagementScreenState();
}

class _AdminQuestionManagementScreenState
    extends ConsumerState<AdminQuestionManagementScreen> {
  String? _selectedSubjectId;
  String? _displayedSubjectId;
  List<AdminQuestion> _displayedQuestions = <AdminQuestion>[];

  void _syncSelectedSubject(List<ApiSubject> subjects) {
    if (subjects.isEmpty) {
      _selectedSubjectId = null;
      return;
    }

    final initial = widget.initialSubjectId;
    if (_selectedSubjectId == null && initial != null) {
      final found = subjects.any((subject) => subject.id == initial);
      if (found) {
        _selectedSubjectId = initial;
      }
    }

    _selectedSubjectId ??= subjects.first.id;
    final stillExists =
        subjects.any((subject) => subject.id == _selectedSubjectId);
    if (!stillExists) {
      _selectedSubjectId = subjects.first.id;
    }
  }

  void _syncDisplayedQuestions(String subjectId, List<AdminQuestion> data) {
    if (_displayedSubjectId != subjectId ||
        !_isSameQuestionOrder(_displayedQuestions, data)) {
      _displayedSubjectId = subjectId;
      _displayedQuestions = List<AdminQuestion>.from(data);
    }
  }

  bool _isSameQuestionOrder(
    List<AdminQuestion> current,
    List<AdminQuestion> incoming,
  ) {
    if (current.length != incoming.length) {
      return false;
    }
    for (var index = 0; index < current.length; index += 1) {
      if (current[index].id != incoming[index].id ||
          current[index].orderIndex != incoming[index].orderIndex) {
        return false;
      }
    }
    return true;
  }

  Future<void> _showQuickCreateQuestionDialog(String subjectId) async {
    final created = await showDialog<AdminQuestion>(
      context: context,
      builder: (_) => _QuickCreateQuestionDialog(subjectId: subjectId),
    );

    if (!mounted || created == null) {
      return;
    }

    AppSnackBar.success(
      context,
      'Pertanyaan berhasil dibuat. Lanjutkan edit detail.',
    );
    context.push('/admin/questions/$subjectId/${created.id}/edit');
  }

  Future<void> _onReorder({
    required int oldIndex,
    required int newIndex,
    required String subjectId,
  }) async {
    if (oldIndex < 0 || oldIndex >= _displayedQuestions.length) {
      return;
    }

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (newIndex < 0 || newIndex >= _displayedQuestions.length) {
      return;
    }

    setState(() {
      final moved = _displayedQuestions.removeAt(oldIndex);
      _displayedQuestions.insert(newIndex, moved);
    });

    final orderedIds = _displayedQuestions.map((item) => item.id).toList();
    final reordered =
        await ref.read(adminQuestionActionProvider.notifier).reorder(
              subjectId: subjectId,
              orderedQuestionIds: orderedIds,
            );

    if (!mounted) {
      return;
    }

    if (reordered != null) {
      AppSnackBar.success(context, 'Urutan pertanyaan berhasil diperbarui.');
      setState(() {
        _displayedQuestions = List<AdminQuestion>.from(reordered);
      });
      return;
    }

    final error = ref.read(adminQuestionActionProvider).errorMessage;
    AppSnackBar.error(
        context, error ?? 'Urutan pertanyaan belum berhasil disimpan.');

    final refreshed =
        await ref.refresh(questionListBySubjectProvider(subjectId).future);
    if (!mounted) {
      return;
    }
    setState(() {
      _displayedQuestions = List<AdminQuestion>.from(refreshed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectListProvider);
    final actionState = ref.watch(adminQuestionActionProvider);

    return AdminLayout(
      title: 'Kelola Soal',
      subtitle: 'Atur bank soal dan urutan soal per mata pelajaran.',
      activeSection: AdminSection.questions,
      child: subjectsAsync.when(
        data: (subjects) {
          _syncSelectedSubject(subjects);
          final selectedSubjectId = _selectedSubjectId;
          if (selectedSubjectId == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const AppCard(
                  title: 'Mata pelajaran belum tersedia',
                  subtitle:
                      'Tambahkan mata pelajaran terlebih dahulu sebelum membuat soal.',
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Buka Kelola Mata Pelajaran',
                  onPressed: () => context.go('/admin/subjects'),
                ),
              ],
            );
          }

          final questionsAsync =
              ref.watch(questionListBySubjectProvider(selectedSubjectId));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppCard(
                title: 'Pilih Mata Pelajaran',
                child: DropdownButtonFormField<String>(
                  initialValue: selectedSubjectId,
                  decoration: const InputDecoration(
                    labelText: 'Mata Pelajaran',
                  ),
                  items: subjects
                      .map(
                        (subject) => DropdownMenuItem<String>(
                          value: subject.id,
                          child: Text(subject.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedSubjectId = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Buat Soal Cepat',
                loading: actionState.isCreating,
                disabled: actionState.isUpdating ||
                    actionState.isDeleting ||
                    actionState.isReordering,
                onPressed: () =>
                    _showQuickCreateQuestionDialog(selectedSubjectId),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: questionsAsync.when(
                  data: (questions) {
                    _syncDisplayedQuestions(selectedSubjectId, questions);
                    if (_displayedQuestions.isEmpty) {
                      return const AppCard(
                        title: 'Soal masih kosong',
                        subtitle: 'Belum ada soal untuk mata pelajaran ini.',
                      );
                    }

                    return AppCard(
                      title: 'Daftar Soal',
                      subtitle:
                          'Ketuk soal untuk ubah atau hapus. Geser untuk mengubah urutan.',
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _displayedQuestions.length,
                        onReorder: (oldIndex, newIndex) => _onReorder(
                          oldIndex: oldIndex,
                          newIndex: newIndex,
                          subjectId: selectedSubjectId,
                        ),
                        itemBuilder: (context, index) {
                          final question = _displayedQuestions[index];
                          return Container(
                            key: ValueKey<String>(question.id),
                            margin:
                                const EdgeInsets.only(bottom: AppSpacing.xs),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: ListTile(
                              onTap: () => context.push(
                                '/admin/questions/$selectedSubjectId/${question.id}/edit',
                              ),
                              leading: CircleAvatar(
                                radius: 15,
                                child: Text('${index + 1}'),
                              ),
                              title: Text(
                                question.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'Poin: ${question.weight} | Jawaban Benar: ${question.correctAnswer}',
                              ),
                              trailing: ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const AppCard(
                    title: 'Gagal memuat pertanyaan',
                    subtitle:
                        'Daftar pertanyaan belum bisa dimuat. Coba lagi sebentar.',
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const AppCard(
          title: 'Gagal memuat mata pelajaran',
          subtitle:
              'Data mata pelajaran belum bisa dimuat. Coba lagi sebentar.',
        ),
      ),
    );
  }
}

class _QuickCreateQuestionDialog extends ConsumerStatefulWidget {
  const _QuickCreateQuestionDialog({
    required this.subjectId,
  });

  final String subjectId;

  @override
  ConsumerState<_QuickCreateQuestionDialog> createState() =>
      _QuickCreateQuestionDialogState();
}

class _QuickCreateQuestionDialogState
    extends ConsumerState<_QuickCreateQuestionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _weightController =
      TextEditingController(text: '10');

  @override
  void dispose() {
    _questionController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final created =
        await ref.read(adminQuestionActionProvider.notifier).quickCreate(
              subjectId: widget.subjectId,
              text: _questionController.text.trim(),
              weight: int.parse(_weightController.text.trim()),
            );

    if (!mounted) {
      return;
    }

    if (created != null) {
      Navigator.of(context).pop(created);
      return;
    }

    final error = ref.read(adminQuestionActionProvider).errorMessage;
    AppSnackBar.error(context, error ?? 'Pertanyaan belum berhasil dibuat.');
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(adminQuestionActionProvider);
    return AlertDialog(
      title: const Text('Buat Soal Cepat'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Isi data utama dulu (teks soal dan poin). Opsi jawaban bisa dilengkapi di halaman edit.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Teks Soal',
                hintText: 'Tulis pertanyaan di sini',
              ),
              minLines: 2,
              maxLines: 5,
              validator: QuestionFormFields.validateQuestionText,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Poin Soal',
                hintText: 'Contoh: 10',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: false,
                signed: false,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: QuestionFormFields.validateWeight,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed:
              actionState.isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: actionState.isCreating ? null : _submit,
          child: actionState.isCreating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Buat & Lanjut Edit'),
        ),
      ],
    );
  }
}
