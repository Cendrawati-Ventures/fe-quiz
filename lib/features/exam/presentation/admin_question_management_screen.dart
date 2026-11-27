import 'dart:convert';

import 'package:file_picker/file_picker.dart';
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

  num _totalWeight(List<AdminQuestion> questions) {
    return questions.fold<num>(0, (total, item) => total + item.weight);
  }

  bool _isWeightBalanced(num totalWeight) {
    return (totalWeight - 100).abs() < 0.001;
  }

  String _weightSummary(num totalWeight) {
    final diff = 100 - totalWeight;
    if (_isWeightBalanced(totalWeight)) {
      return 'Total bobot sudah pas 100.';
    }
    if (diff > 0) {
      return 'Kurang ${_formatWeight(diff)} poin untuk mencapai 100.';
    }
    return 'Melebihi ${_formatWeight(-diff)} poin dari batas 100.';
  }

  Color _weightStatusColor(BuildContext context, num totalWeight) {
    if (_isWeightBalanced(totalWeight)) {
      return const Color(0xFF1B7A42);
    }
    if (totalWeight < 100) {
      return const Color(0xFFD08900);
    }
    return Theme.of(context).colorScheme.error;
  }

  String _formatWeight(num value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.001) {
      return rounded.toInt().toString();
    }
    return value.toStringAsFixed(1);
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
    await _openQuestionEditor(
      subjectId: subjectId,
      questionId: created.id,
    );
  }

  Future<void> _openQuestionEditor({
    required String subjectId,
    required String questionId,
  }) async {
    await context.push('/admin/questions/$subjectId/$questionId/edit');
    if (!mounted) {
      return;
    }

    final refreshed =
        await ref.refresh(questionListBySubjectProvider(subjectId).future);
    if (!mounted) {
      return;
    }

    setState(() {
      _displayedSubjectId = subjectId;
      _displayedQuestions = List<AdminQuestion>.from(refreshed);
    });
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
      subtitle: 'Atur bank soal dan urutan soal per ujian.',
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
                  title: 'Ujian belum tersedia',
                  subtitle:
                      'Tambahkan ujian terlebih dahulu sebelum membuat soal.',
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Buka Kelola Ujian',
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
                title: 'Pilih Ujian',
                child: DropdownButtonFormField<String>(
                  initialValue: selectedSubjectId,
                  decoration: const InputDecoration(
                    labelText: 'Ujian',
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
                    final totalWeight = _totalWeight(_displayedQuestions);
                    final weightOk = _isWeightBalanced(totalWeight);
                    final weightColor =
                        _weightStatusColor(context, totalWeight);

                    if (_displayedQuestions.isEmpty) {
                      return AppCard(
                        title: 'Soal masih kosong',
                        subtitle: 'Belum ada soal untuk ujian ini.',
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: weightColor.withValues(alpha: 0.1),
                            border: Border.all(
                              color: weightColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                weightOk
                                    ? Icons.check_circle_rounded
                                    : Icons.warning_amber_rounded,
                                color: weightColor,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Bobot: ${_formatWeight(totalWeight)}/100. ${_weightSummary(totalWeight)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: weightColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return AppCard(
                      title: 'Daftar Soal',
                      subtitle:
                          'Ketuk soal untuk ubah atau hapus. Geser untuk mengubah urutan.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: weightColor.withValues(alpha: 0.1),
                              border: Border.all(
                                color: weightColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  weightOk
                                      ? Icons.check_circle_rounded
                                      : Icons.warning_amber_rounded,
                                  color: weightColor,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Bobot: ${_formatWeight(totalWeight)}/100. ${_weightSummary(totalWeight)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: weightColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ReorderableListView.builder(
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
                                margin: const EdgeInsets.only(
                                    bottom: AppSpacing.xs),
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
                                  onTap: () => _openQuestionEditor(
                                    subjectId: selectedSubjectId,
                                    questionId: question.id,
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
                                    'Tipe: ${adminQuestionTypeLabel(question.type)} | Bobot: ${question.weight}',
                                  ),
                                  trailing: ReorderableDragStartListener(
                                    index: index,
                                    child: const Icon(Icons.drag_handle),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
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
          title: 'Gagal memuat ujian',
          subtitle: 'Data ujian belum bisa dimuat. Coba lagi sebentar.',
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
  QuestionType _selectedType = QuestionType.single;
  String? _imageData;

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

    final payload = _buildInitialPayload(_selectedType);
    final created = await ref.read(adminQuestionActionProvider.notifier).create(
          subjectId: widget.subjectId,
          type: _selectedType,
          text: _questionController.text.trim(),
          weight: int.parse(_weightController.text.trim()),
          options: payload.options,
          correctAnswer: payload.correctAnswer,
          imageData: _imageData,
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
              'Pilih tipe soal lalu isi data utama. Detail opsi/jawaban dapat dilengkapi pada halaman edit.',
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<QuestionType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Tipe Soal',
              ),
              items: QuestionType.values
                  .map(
                    (type) => DropdownMenuItem<QuestionType>(
                      value: type,
                      child: Text(adminQuestionTypeLabel(type)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedType = value;
                });
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Teks Soal',
                hintText: 'Tulis pertanyaan di sini',
              ),
              minLines: 2,
              maxLines: 5,
              validator: _validateQuestionText,
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
              validator: _validateWeight,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildImageInput(),
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

  _InitialQuestionPayload _buildInitialPayload(QuestionType type) {
    final defaultOptions = adminDefaultQuestionOptions
        .map((option) => option.toJson())
        .toList(growable: false);

    if (type == QuestionType.single) {
      return _InitialQuestionPayload(
        options: defaultOptions,
        correctAnswer: 'A',
      );
    }

    if (type == QuestionType.multi) {
      return _InitialQuestionPayload(
        options: defaultOptions,
        correctAnswer: <String>['A'],
      );
    }

    if (type == QuestionType.essay) {
      return const _InitialQuestionPayload(
        options: <String, dynamic>{},
        correctAnswer: '',
      );
    }

    return _InitialQuestionPayload(
      options: <String, dynamic>{
        'parentText': '',
        'subQuestions': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'item-1',
            'text': 'Sub-soal 1',
            'type': 'single',
            'options': defaultOptions,
          },
        ],
      },
      correctAnswer: <String, dynamic>{
        'item-1': 'A',
      },
    );
  }

  Widget _buildImageInput() {
    final imageBytes = _decodeImageData(_imageData);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Gambar Soal (Opsional)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Maksimal 2MB',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (imageBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              imageBytes,
              height: 130,
              fit: BoxFit.contain,
            ),
          )
        else
          Container(
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            alignment: Alignment.center,
            child: const Text('Belum ada gambar'),
          ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: _pickImage,
                child:
                    Text(imageBytes == null ? 'Pilih Gambar' : 'Ganti Gambar'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: imageBytes == null
                    ? null
                    : () {
                        setState(() {
                          _imageData = null;
                        });
                      },
                child: const Text('Hapus'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      AppSnackBar.error(context, 'Gagal membaca file gambar.');
      return;
    }

    if (bytes.length > 2 * 1024 * 1024) {
      AppSnackBar.error(context, 'Ukuran gambar maksimal 2MB.');
      return;
    }

    final mime = _guessImageMimeType(file.name);
    if (mime == null) {
      AppSnackBar.error(context, 'Format gambar tidak didukung.');
      return;
    }

    setState(() {
      _imageData = 'data:$mime;base64,${base64Encode(bytes)}';
    });
  }

  String? _guessImageMimeType(String? fileName) {
    final name = (fileName ?? '').trim().toLowerCase();
    if (name.endsWith('.png')) {
      return 'image/png';
    }
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (name.endsWith('.webp')) {
      return 'image/webp';
    }
    if (name.endsWith('.gif')) {
      return 'image/gif';
    }
    if (name.endsWith('.bmp')) {
      return 'image/bmp';
    }
    return null;
  }

  Uint8List? _decodeImageData(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }

    final match =
        RegExp(r'^data:image\/[a-zA-Z0-9.+-]+;base64,(.+)$').firstMatch(value);
    if (match == null) {
      return null;
    }

    final encoded = match.group(1);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  String? _validateQuestionText(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Teks soal wajib diisi.';
    }
    if (text.length < 3) {
      return 'Teks soal minimal 3 karakter.';
    }
    return null;
  }

  String? _validateWeight(String? value) {
    final text = value?.trim() ?? '';
    final number = int.tryParse(text);
    if (number == null) {
      return 'Poin harus berupa angka.';
    }
    if (number <= 0) {
      return 'Poin harus lebih dari 0.';
    }
    if (number > 100) {
      return 'Poin maksimal 100.';
    }
    return null;
  }
}

class _InitialQuestionPayload {
  const _InitialQuestionPayload({
    required this.options,
    required this.correctAnswer,
  });

  final Object options;
  final Object correctAnswer;
}
