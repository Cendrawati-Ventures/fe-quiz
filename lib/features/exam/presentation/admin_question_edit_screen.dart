import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_button.dart';
import '../../../shared/components/app_card.dart';
import '../../../shared/components/app_snackbar.dart';
import '../model/exam_models.dart';
import '../state/admin_question_state.dart';
import 'widgets/question_form_fields.dart';

class AdminQuestionEditScreen extends ConsumerStatefulWidget {
  const AdminQuestionEditScreen({
    required this.subjectId,
    required this.questionId,
    super.key,
  });

  final String subjectId;
  final String questionId;

  @override
  ConsumerState<AdminQuestionEditScreen> createState() =>
      _AdminQuestionEditScreenState();
}

class _AdminQuestionEditScreenState extends ConsumerState<AdminQuestionEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  late final List<TextEditingController> _optionControllers;
  int? _correctAnswerIndex;
  bool _initialized = false;

  static const List<String> _optionValues = <String>['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    _optionControllers = List<TextEditingController>.generate(
      4,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _weightController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initForm(AdminQuestion question) {
    if (_initialized) {
      return;
    }

    _questionController.text = question.text;
    _weightController.text = question.weight.toStringAsFixed(0);

    final optionByValue = <String, String>{};
    for (final option in question.options) {
      optionByValue[option.value.toUpperCase()] = option.label;
    }

    for (var index = 0; index < _optionValues.length; index += 1) {
      final key = _optionValues[index];
      _optionControllers[index].text = optionByValue[key] ?? 'Opsi $key';
    }

    final selectedIndex = _optionValues.indexOf(question.correctAnswer.toUpperCase());
    _correctAnswerIndex = selectedIndex >= 0 ? selectedIndex : 0;
    _initialized = true;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_correctAnswerIndex == null) {
      AppSnackBar.error(context, 'Pilih jawaban yang benar terlebih dahulu.');
      return;
    }

    final labels = _optionControllers
        .map((controller) => controller.text.trim())
        .toList();
    if (labels.toSet().length != labels.length) {
      AppSnackBar.error(context, 'Teks setiap opsi harus berbeda.');
      return;
    }

    final options = <AdminQuestionOption>[];
    for (var index = 0; index < 4; index += 1) {
      options.add(
        AdminQuestionOption(
          value: _optionValues[index],
          label: _optionControllers[index].text.trim(),
        ),
      );
    }

    final updated = await ref.read(adminQuestionActionProvider.notifier).update(
          subjectId: widget.subjectId,
          questionId: widget.questionId,
          text: _questionController.text.trim(),
          weight: int.parse(_weightController.text.trim()),
          options: options,
          correctAnswer: _optionValues[_correctAnswerIndex!],
        );

    if (!mounted) {
      return;
    }

    if (updated != null) {
      AppSnackBar.success(context, 'Pertanyaan berhasil diperbarui.');
      context.go('/admin/questions?subjectId=${widget.subjectId}');
      return;
    }

    final error = ref.read(adminQuestionActionProvider).errorMessage;
    AppSnackBar.error(context, error ?? 'Perubahan pertanyaan belum berhasil disimpan.');
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Pertanyaan'),
          content: const Text(
            'Yakin ingin menghapus pertanyaan ini? Tindakan ini tidak bisa dibatalkan.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final deleted = await ref.read(adminQuestionActionProvider.notifier).delete(
          subjectId: widget.subjectId,
          questionId: widget.questionId,
        );

    if (!mounted) {
      return;
    }

    if (deleted) {
      AppSnackBar.success(context, 'Pertanyaan berhasil dihapus.');
      context.go('/admin/questions?subjectId=${widget.subjectId}');
      return;
    }

    final error = ref.read(adminQuestionActionProvider).errorMessage;
    AppSnackBar.error(context, error ?? 'Pertanyaan belum berhasil dihapus.');
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(questionListBySubjectProvider(widget.subjectId));
    final actionState = ref.watch(adminQuestionActionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Question')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: questionsAsync.when(
          data: (questions) {
            AdminQuestion? question;
            for (final item in questions) {
              if (item.id == widget.questionId) {
                question = item;
                break;
              }
            }

            if (question == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const AppCard(
                    title: 'Pertanyaan tidak ditemukan',
                    subtitle: 'Data pertanyaan belum tersedia atau sudah dihapus.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Kembali ke Question Management',
                    onPressed: () =>
                        context.go('/admin/questions?subjectId=${widget.subjectId}'),
                  ),
                ],
              );
            }

            _initForm(question);

            return Form(
              key: _formKey,
              child: ListView(
                children: <Widget>[
                  AppCard(
                    title: 'Edit Pertanyaan Pilihan Ganda',
                    subtitle:
                        'Soal harus memiliki tepat 4 opsi jawaban dan 1 jawaban benar.',
                    child: QuestionFormFields(
                      questionTextController: _questionController,
                      weightController: _weightController,
                      optionControllers: _optionControllers,
                      correctAnswerIndex: _correctAnswerIndex,
                      onCorrectAnswerChanged: (value) {
                        setState(() {
                          _correctAnswerIndex = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Simpan Perubahan',
                    loading: actionState.isUpdating,
                    disabled: actionState.isDeleting,
                    onPressed: _save,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Hapus Pertanyaan',
                    variant: AppButtonVariant.danger,
                    loading: actionState.isDeleting,
                    disabled: actionState.isUpdating,
                    onPressed: _delete,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Kembali ke Question Management',
                    variant: AppButtonVariant.secondary,
                    disabled: actionState.isUpdating || actionState.isDeleting,
                    onPressed: () =>
                        context.go('/admin/questions?subjectId=${widget.subjectId}'),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const AppCard(
            title: 'Gagal memuat pertanyaan',
            subtitle: 'Data pertanyaan belum bisa dimuat. Coba lagi sebentar.',
          ),
        ),
      ),
    );
  }
}
