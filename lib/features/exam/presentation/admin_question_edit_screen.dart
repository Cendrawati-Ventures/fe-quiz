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
import 'widgets/admin_layout.dart';

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

class _AdminQuestionEditScreenState
    extends ConsumerState<AdminQuestionEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _groupParentController = TextEditingController();

  late final List<TextEditingController> _optionControllers;
  late final List<String?> _optionImageData;
  final List<_GroupQuestionEditorItem> _groupItems =
      <_GroupQuestionEditorItem>[];

  QuestionType _selectedType = QuestionType.single;
  int? _singleCorrectAnswerIndex;
  Set<int> _multiCorrectAnswerIndexes = <int>{0};
  String? _imageData;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _optionControllers = List<TextEditingController>.generate(
      adminDefaultOptionValues.length,
      (_) => TextEditingController(),
    );
    _optionImageData = List<String?>.filled(
      adminDefaultOptionValues.length,
      null,
      growable: false,
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _weightController.dispose();
    _groupParentController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    _disposeGroupItems();
    super.dispose();
  }

  void _disposeGroupItems() {
    for (final item in _groupItems) {
      item.dispose();
    }
    _groupItems.clear();
  }

  void _initForm(AdminQuestion question) {
    if (_initialized) {
      return;
    }

    _questionController.text = question.text;
    _weightController.text = question.weight.toStringAsFixed(0);
    _selectedType = question.type;
    _imageData = question.imageData;

    _setOptionControllersFromRaw(question.options);

    if (_selectedType == QuestionType.single) {
      final selected = parseAnswerValueList(question.correctAnswer);
      _singleCorrectAnswerIndex =
          _indexOfOptionValue(selected.isNotEmpty ? selected.first : 'A');
    } else if (_selectedType == QuestionType.multi) {
      final selected = parseAnswerValueList(question.correctAnswer);
      final indexes =
          selected.map(_indexOfOptionValue).whereType<int>().toSet();
      _multiCorrectAnswerIndexes = indexes.isEmpty ? <int>{0} : indexes;
    } else {
      _initGroupEditor(
        rawOptions: question.options,
        rawCorrectAnswer: question.correctAnswer,
      );
    }

    if (_groupItems.isEmpty) {
      _groupItems.add(_createDefaultGroupItem());
    }

    _initialized = true;
  }

  void _setOptionControllersFromRaw(Object? rawOptions) {
    final options = parseAdminChoiceOptions(rawOptions);
    final byValue = <String, AdminQuestionOption>{
      for (final option in options) option.value.toUpperCase(): option,
    };

    for (var index = 0; index < adminDefaultOptionValues.length; index += 1) {
      final value = adminDefaultOptionValues[index];
      final option = byValue[value];
      _optionControllers[index].text = option?.label ?? 'Opsi $value';
      _optionImageData[index] = option?.imageData;
    }
  }

  void _initGroupEditor({
    required Object? rawOptions,
    required Object? rawCorrectAnswer,
  }) {
    _disposeGroupItems();

    final optionsMap =
        rawOptions is Map<String, dynamic> ? rawOptions : <String, dynamic>{};
    final rawSubQuestions = _extractRawSubQuestions(rawOptions);
    final correctAnswerMap = rawCorrectAnswer is Map<String, dynamic>
        ? rawCorrectAnswer
        : <String, dynamic>{};

    _groupParentController.text = _extractGroupParentText(optionsMap);

    for (var index = 0; index < rawSubQuestions.length; index += 1) {
      final raw = rawSubQuestions[index];
      final id = _extractGroupSubQuestionId(raw, index);
      final subType = _extractGroupSubQuestionType(raw);
      final promptText = (raw['text'] as String? ?? '').trim();
      final options = parseAdminChoiceOptions(raw['options']);
      final selectedAnswer = correctAnswerMap[id];
      final selectedValues = parseAnswerValueList(selectedAnswer);

      final singleIndex = selectedValues.isNotEmpty
          ? _indexOfOptionValue(selectedValues.first)
          : 0;
      final multiIndexes =
          selectedValues.map(_indexOfOptionValue).whereType<int>().toSet();

      _groupItems.add(
        _GroupQuestionEditorItem(
          id: id,
          promptController: TextEditingController(
            text: promptText.isEmpty ? 'Sub-soal ${index + 1}' : promptText,
          ),
          optionControllers: _buildOptionControllers(options),
          type: subType,
          singleCorrectIndex: singleIndex ?? 0,
          multiCorrectIndexes: multiIndexes.isEmpty ? <int>{0} : multiIndexes,
        ),
      );
    }

    if (_groupItems.isEmpty) {
      _groupItems.add(_createDefaultGroupItem());
    }
  }

  List<Map<String, dynamic>> _extractRawSubQuestions(Object? rawOptions) {
    if (rawOptions is List<dynamic>) {
      return rawOptions.whereType<Map<String, dynamic>>().toList();
    }

    if (rawOptions is! Map<String, dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final dynamic candidate = rawOptions['subQuestions'] ??
        rawOptions['sub_questions'] ??
        rawOptions['subquestions'] ??
        rawOptions['questions'] ??
        rawOptions['items'];

    if (candidate is List<dynamic>) {
      return candidate.whereType<Map<String, dynamic>>().toList();
    }

    return <Map<String, dynamic>>[];
  }

  String _extractGroupParentText(Map<String, dynamic> optionsMap) {
    final dynamic candidate = optionsMap['parentText'] ??
        optionsMap['parent'] ??
        optionsMap['context'] ??
        optionsMap['stem'];
    return candidate is String ? candidate.trim() : '';
  }

  String _extractGroupSubQuestionId(Map<String, dynamic> raw, int index) {
    final dynamic rawId =
        raw['id'] ?? raw['questionId'] ?? raw['subQuestionId'] ?? raw['key'];
    if (rawId is String && rawId.trim().isNotEmpty) {
      return rawId.trim();
    }
    return 'item-${index + 1}';
  }

  QuestionType _extractGroupSubQuestionType(Map<String, dynamic> raw) {
    final rawType = (raw['type'] as String? ?? '').trim().toLowerCase();
    if (rawType == questionTypeToString(QuestionType.multi)) {
      return QuestionType.multi;
    }
    return QuestionType.single;
  }

  List<TextEditingController> _buildOptionControllers(
    List<AdminQuestionOption> options,
  ) {
    final byValue = <String, String>{
      for (final option in options) option.value.toUpperCase(): option.label,
    };

    return List<TextEditingController>.generate(
      adminDefaultOptionValues.length,
      (index) {
        final value = adminDefaultOptionValues[index];
        return TextEditingController(text: byValue[value] ?? 'Opsi $value');
      },
    );
  }

  _GroupQuestionEditorItem _createDefaultGroupItem() {
    final label = _groupItems.length + 1;
    final uniqueId = 'item-${DateTime.now().microsecondsSinceEpoch}-$label';
    return _GroupQuestionEditorItem(
      id: uniqueId,
      promptController: TextEditingController(text: 'Sub-soal $label'),
      optionControllers: List<TextEditingController>.generate(
        adminDefaultOptionValues.length,
        (index) => TextEditingController(
          text: 'Opsi ${adminDefaultOptionValues[index]}',
        ),
      ),
      type: QuestionType.single,
      singleCorrectIndex: 0,
      multiCorrectIndexes: <int>{0},
    );
  }

  int? _indexOfOptionValue(String optionValue) {
    final index = adminDefaultOptionValues.indexOf(optionValue.toUpperCase());
    if (index < 0) {
      return null;
    }
    return index;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_selectedType == QuestionType.single &&
        _singleCorrectAnswerIndex == null) {
      AppSnackBar.error(context, 'Pilih jawaban benar untuk tipe PGS.');
      return;
    }

    if (_selectedType == QuestionType.multi &&
        _multiCorrectAnswerIndexes.isEmpty) {
      AppSnackBar.error(
          context, 'Pilih minimal satu jawaban benar untuk tipe multi.');
      return;
    }

    if (_selectedType == QuestionType.group && _groupItems.isEmpty) {
      AppSnackBar.error(
          context, 'Tambahkan minimal satu sub-soal untuk tipe group.');
      return;
    }

    if (_selectedType != QuestionType.group) {
      if (_hasDuplicateOptionLabels(_optionControllers)) {
        AppSnackBar.error(context, 'Setiap opsi jawaban harus berbeda.');
        return;
      }
    } else {
      for (final item in _groupItems) {
        if (_hasDuplicateOptionLabels(item.optionControllers)) {
          AppSnackBar.error(
            context,
            'Setiap opsi pada sub-soal "${item.promptController.text.trim()}" harus berbeda.',
          );
          return;
        }

        if (item.type == QuestionType.single &&
            item.singleCorrectIndex == null) {
          AppSnackBar.error(
            context,
            'Pilih jawaban benar untuk sub-soal "${item.promptController.text.trim()}".',
          );
          return;
        }

        if (item.type == QuestionType.multi &&
            item.multiCorrectIndexes.isEmpty) {
          AppSnackBar.error(
            context,
            'Pilih minimal satu jawaban benar untuk sub-soal "${item.promptController.text.trim()}".',
          );
          return;
        }
      }
    }

    final payload = _buildQuestionPayload();
    final updated = await ref.read(adminQuestionActionProvider.notifier).update(
          subjectId: widget.subjectId,
          questionId: widget.questionId,
          type: payload.type,
          text: payload.text,
          weight: payload.weight,
          options: payload.options,
          correctAnswer: payload.correctAnswer,
          imageData: payload.imageData,
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
    AppSnackBar.error(
      context,
      error ?? 'Perubahan pertanyaan belum berhasil disimpan.',
    );
  }

  _QuestionPayload _buildQuestionPayload() {
    final text = _questionController.text.trim();
    final weight = int.parse(_weightController.text.trim());

    if (_selectedType == QuestionType.single) {
      final options = _buildChoiceOptionJson(
        _optionControllers,
        imageData: _optionImageData,
      );
      final correctAnswer =
          adminDefaultOptionValues[_singleCorrectAnswerIndex ?? 0];
      return _QuestionPayload(
        type: _selectedType,
        text: text,
        weight: weight,
        options: options,
        correctAnswer: correctAnswer,
        imageData: _imageData,
      );
    }

    if (_selectedType == QuestionType.multi) {
      final options = _buildChoiceOptionJson(
        _optionControllers,
        imageData: _optionImageData,
      );
      final correctAnswer = _multiCorrectAnswerIndexes
          .map((index) => adminDefaultOptionValues[index])
          .toList()
        ..sort((a, b) => a.compareTo(b));
      return _QuestionPayload(
        type: _selectedType,
        text: text,
        weight: weight,
        options: options,
        correctAnswer: correctAnswer,
        imageData: _imageData,
      );
    }

    final subQuestions = <Map<String, dynamic>>[];
    final correctAnswer = <String, dynamic>{};

    for (var index = 0; index < _groupItems.length; index += 1) {
      final item = _groupItems[index];
      final subQuestionId =
          item.id.trim().isEmpty ? 'item-${index + 1}' : item.id.trim();
      final optionJson = _buildChoiceOptionJson(item.optionControllers);

      subQuestions.add(
        <String, dynamic>{
          'id': subQuestionId,
          'text': item.promptController.text.trim(),
          'type': questionTypeToString(item.type),
          'options': optionJson,
        },
      );

      if (item.type == QuestionType.multi) {
        final selected = item.multiCorrectIndexes
            .map((itemIndex) => adminDefaultOptionValues[itemIndex])
            .toList()
          ..sort((a, b) => a.compareTo(b));
        correctAnswer[subQuestionId] = selected;
      } else {
        final selectedIndex = item.singleCorrectIndex ?? 0;
        correctAnswer[subQuestionId] = adminDefaultOptionValues[selectedIndex];
      }
    }

    final options = <String, dynamic>{
      if (_groupParentController.text.trim().isNotEmpty)
        'parentText': _groupParentController.text.trim(),
      'subQuestions': subQuestions,
    };

    return _QuestionPayload(
      type: _selectedType,
      text: text,
      weight: weight,
      options: options,
      correctAnswer: correctAnswer,
      imageData: _imageData,
    );
  }

  List<Map<String, dynamic>> _buildChoiceOptionJson(
    List<TextEditingController> controllers, {
    List<String?>? imageData,
  }) {
    return List<Map<String, dynamic>>.generate(
      adminDefaultOptionValues.length,
      (index) => <String, dynamic>{
        'value': adminDefaultOptionValues[index],
        'label': controllers[index].text.trim(),
        if (imageData != null && imageData[index]?.isNotEmpty == true)
          'imageData': imageData[index],
      },
    );
  }

  bool _hasDuplicateOptionLabels(List<TextEditingController> controllers) {
    final labels = controllers
        .map((controller) => controller.text.trim().toLowerCase())
        .toList();
    return labels.toSet().length != labels.length;
  }

  Future<void> _pickImage() async {
    final imageData = await _selectImageData(
      maxBytes: 2 * 1024 * 1024,
      maxSizeLabel: '2MB',
    );
    if (imageData == null || !mounted) {
      return;
    }
    setState(() {
      _imageData = imageData;
    });
  }

  Future<void> _pickOptionImage(int index) async {
    final imageData = await _selectImageData(
      maxBytes: 512 * 1024,
      maxSizeLabel: '512KB',
    );
    if (imageData == null || !mounted) {
      return;
    }
    setState(() {
      _optionImageData[index] = imageData;
    });
  }

  Future<String?> _selectImageData({
    required int maxBytes,
    required String maxSizeLabel,
  }) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );

    if (!mounted || picked == null || picked.files.isEmpty) {
      return null;
    }

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      AppSnackBar.error(context, 'Gagal membaca file gambar.');
      return null;
    }

    if (bytes.length > maxBytes) {
      AppSnackBar.error(context, 'Ukuran gambar maksimal $maxSizeLabel.');
      return null;
    }

    final mime = _guessImageMimeType(file.name);
    if (mime == null) {
      AppSnackBar.error(context, 'Format gambar tidak didukung.');
      return null;
    }

    return 'data:$mime;base64,${base64Encode(bytes)}';
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
    final questionsAsync =
        ref.watch(questionListBySubjectProvider(widget.subjectId));
    final actionState = ref.watch(adminQuestionActionProvider);

    return AdminLayout(
      title: 'Ubah Soal',
      subtitle: 'Atur tipe soal, opsi, bobot, dan kunci jawaban.',
      activeSection: AdminSection.questions,
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
                  subtitle:
                      'Data pertanyaan belum tersedia atau sudah dihapus.',
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Kembali ke Kelola Soal',
                  onPressed: () => context
                      .go('/admin/questions?subjectId=${widget.subjectId}'),
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
                  title: 'Editor Soal',
                  subtitle: 'Dukung 3 varian: PGS, PGK-MCMA, dan PGK-Kategori.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
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
                            if (_selectedType == QuestionType.single &&
                                _singleCorrectAnswerIndex == null) {
                              _singleCorrectAnswerIndex = 0;
                            }
                            if (_selectedType == QuestionType.multi &&
                                _multiCorrectAnswerIndexes.isEmpty) {
                              _multiCorrectAnswerIndexes = <int>{0};
                            }
                            if (_selectedType == QuestionType.group &&
                                _groupItems.isEmpty) {
                              _groupItems.add(_createDefaultGroupItem());
                            }
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
                        maxLines: 6,
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
                      _buildImageEditorSection(),
                      const SizedBox(height: AppSpacing.md),
                      if (_selectedType == QuestionType.single)
                        _buildSingleChoiceEditor()
                      else if (_selectedType == QuestionType.multi)
                        _buildMultiChoiceEditor()
                      else
                        _buildGroupEditor(),
                    ],
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
                  label: 'Kembali ke Kelola Soal',
                  variant: AppButtonVariant.secondary,
                  disabled: actionState.isUpdating || actionState.isDeleting,
                  onPressed: () => context
                      .go('/admin/questions?subjectId=${widget.subjectId}'),
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
    );
  }

  Widget _buildImageEditorSection() {
    final bytes = _decodeImageData(_imageData);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Gambar Soal (Opsional)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Format: PNG/JPG/WEBP/GIF/BMP, ukuran maksimal 2MB.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (bytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              height: 180,
              fit: BoxFit.contain,
            ),
          )
        else
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'Belum ada gambar soal',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: AppButton(
                label: bytes == null ? 'Pilih Gambar' : 'Ganti Gambar',
                variant: AppButtonVariant.secondary,
                onPressed: _pickImage,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                label: 'Hapus Gambar',
                variant: AppButtonVariant.secondary,
                disabled: bytes == null,
                onPressed: () {
                  setState(() {
                    _imageData = null;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleChoiceEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'PGS (Single Choice)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Pilih tepat satu jawaban benar.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        RadioGroup<int>(
          groupValue: _singleCorrectAnswerIndex,
          onChanged: (value) {
            setState(() {
              _singleCorrectAnswerIndex = value;
            });
          },
          child: Column(
            children: <Widget>[
              for (var index = 0;
                  index < adminDefaultOptionValues.length;
                  index += 1)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: index == adminDefaultOptionValues.length - 1
                        ? 0
                        : AppSpacing.xs,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Radio<int>(value: index),
                      Expanded(
                        child: _buildChoiceOptionEditor(index),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMultiChoiceEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'PGK-MCMA (Multi Choice)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Pilih satu atau lebih jawaban benar (exact set match saat dinilai).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var index = 0; index < adminDefaultOptionValues.length; index += 1)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == adminDefaultOptionValues.length - 1
                  ? 0
                  : AppSpacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Checkbox(
                  value: _multiCorrectAnswerIndexes.contains(index),
                  onChanged: (_) {
                    setState(() {
                      if (_multiCorrectAnswerIndexes.contains(index)) {
                        _multiCorrectAnswerIndexes.remove(index);
                      } else {
                        _multiCorrectAnswerIndexes.add(index);
                      }
                    });
                  },
                ),
                Expanded(
                  child: _buildChoiceOptionEditor(index),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChoiceOptionEditor(int index) {
    final imageBytes = _decodeImageData(_optionImageData[index]);
    final optionValue = adminDefaultOptionValues[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          controller: _optionControllers[index],
          decoration: InputDecoration(labelText: 'Opsi $optionValue'),
          validator: _validateOptionText,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (imageBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              imageBytes,
              height: 120,
              fit: BoxFit.contain,
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickOptionImage(index),
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  imageBytes == null ? 'Tambah Gambar' : 'Ganti Gambar',
                ),
              ),
            ),
            if (imageBytes != null) ...<Widget>[
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                onPressed: () {
                  setState(() {
                    _optionImageData[index] = null;
                  });
                },
                tooltip: 'Hapus gambar opsi $optionValue',
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
        Text(
          'Gambar jawaban opsional, maksimal 512KB.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildGroupEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'PGK-Kategori (Group)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Setiap sub-soal dinilai per item. Bobot soal dibagi rata ke semua sub-soal.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _groupParentController,
          decoration: const InputDecoration(
            labelText: 'Stimulus / Parent Text (Opsional)',
            hintText: 'Teks pengantar untuk seluruh sub-soal',
          ),
          minLines: 2,
          maxLines: 5,
        ),
        const SizedBox(height: AppSpacing.md),
        for (var index = 0; index < _groupItems.length; index += 1)
          _buildGroupSubQuestionCard(index),
        AppButton(
          label: 'Tambah Sub-soal',
          variant: AppButtonVariant.secondary,
          onPressed: () {
            setState(() {
              _groupItems.add(_createDefaultGroupItem());
            });
          },
        ),
      ],
    );
  }

  Widget _buildGroupSubQuestionCard(int index) {
    final item = _groupItems[index];
    final isMulti = item.type == QuestionType.multi;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Sub-soal ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (_groupItems.length > 1)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        final removed = _groupItems.removeAt(index);
                        removed.dispose();
                      });
                    },
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Hapus sub-soal',
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<QuestionType>(
              initialValue: item.type,
              decoration: const InputDecoration(
                labelText: 'Tipe Jawaban Sub-soal',
              ),
              items: const <DropdownMenuItem<QuestionType>>[
                DropdownMenuItem<QuestionType>(
                  value: QuestionType.single,
                  child: Text('Single'),
                ),
                DropdownMenuItem<QuestionType>(
                  value: QuestionType.multi,
                  child: Text('Multi'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  item.type = value;
                  if (item.type == QuestionType.single) {
                    item.multiCorrectIndexes = <int>{0};
                    item.singleCorrectIndex ??= 0;
                  } else {
                    item.singleCorrectIndex = 0;
                    item.multiCorrectIndexes = item.multiCorrectIndexes.isEmpty
                        ? <int>{0}
                        : item.multiCorrectIndexes;
                  }
                });
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: item.promptController,
              decoration: const InputDecoration(
                labelText: 'Teks Sub-soal',
              ),
              minLines: 2,
              maxLines: 4,
              validator: _validateSubQuestionText,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (isMulti)
              for (var optionIndex = 0;
                  optionIndex < adminDefaultOptionValues.length;
                  optionIndex += 1)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: optionIndex == adminDefaultOptionValues.length - 1
                        ? 0
                        : AppSpacing.xs,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Checkbox(
                        value: item.multiCorrectIndexes.contains(optionIndex),
                        onChanged: (_) {
                          setState(() {
                            if (item.multiCorrectIndexes
                                .contains(optionIndex)) {
                              item.multiCorrectIndexes.remove(optionIndex);
                            } else {
                              item.multiCorrectIndexes.add(optionIndex);
                            }
                          });
                        },
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: item.optionControllers[optionIndex],
                          decoration: InputDecoration(
                            labelText:
                                'Opsi ${adminDefaultOptionValues[optionIndex]}',
                          ),
                          validator: _validateOptionText,
                        ),
                      ),
                    ],
                  ),
                )
            else
              RadioGroup<int>(
                groupValue: item.singleCorrectIndex,
                onChanged: (value) {
                  setState(() {
                    item.singleCorrectIndex = value;
                  });
                },
                child: Column(
                  children: <Widget>[
                    for (var optionIndex = 0;
                        optionIndex < adminDefaultOptionValues.length;
                        optionIndex += 1)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              optionIndex == adminDefaultOptionValues.length - 1
                                  ? 0
                                  : AppSpacing.xs,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Radio<int>(value: optionIndex),
                            Expanded(
                              child: TextFormField(
                                controller: item.optionControllers[optionIndex],
                                decoration: InputDecoration(
                                  labelText:
                                      'Opsi ${adminDefaultOptionValues[optionIndex]}',
                                ),
                                validator: _validateOptionText,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
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

  String? _validateSubQuestionText(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Teks sub-soal wajib diisi.';
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

  String? _validateOptionText(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Opsi wajib diisi.';
    }
    return null;
  }
}

class _QuestionPayload {
  const _QuestionPayload({
    required this.type,
    required this.text,
    required this.weight,
    required this.options,
    required this.correctAnswer,
    required this.imageData,
  });

  final QuestionType type;
  final String text;
  final num weight;
  final Object options;
  final Object correctAnswer;
  final String? imageData;
}

class _GroupQuestionEditorItem {
  _GroupQuestionEditorItem({
    required this.id,
    required this.promptController,
    required this.optionControllers,
    required this.type,
    required this.singleCorrectIndex,
    required this.multiCorrectIndexes,
  });

  final String id;
  final TextEditingController promptController;
  final List<TextEditingController> optionControllers;
  QuestionType type;
  int? singleCorrectIndex;
  Set<int> multiCorrectIndexes;

  void dispose() {
    promptController.dispose();
    for (final controller in optionControllers) {
      controller.dispose();
    }
  }
}
