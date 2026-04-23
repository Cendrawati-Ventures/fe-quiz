import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/theme/spacing.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/components/app_card.dart';
import '../model/exam_models.dart';
import '../state/exam_state.dart';
import 'widgets/admin_layout.dart';

class AdminResultMonitoringScreen extends ConsumerStatefulWidget {
  const AdminResultMonitoringScreen({super.key});

  @override
  ConsumerState<AdminResultMonitoringScreen> createState() =>
      _AdminResultMonitoringScreenState();
}

class _AdminResultMonitoringScreenState
    extends ConsumerState<AdminResultMonitoringScreen> {
  String? _deletingResultId;
  String? _selectedClassName;
  String? _selectedExamId;

  Future<void> _openAudioChunks(ResultResponse result) async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _AdminAudioChunkDialog(result: result),
    );
  }

  Future<void> _openAnswerReview(ResultResponse result) async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _AdminAnswerReviewDialog(result: result),
    );
  }

  Future<void> _deleteResult(ResultResponse result) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus hasil ujian'),
          content: Text(
            'Hasil ujian untuk peserta "${result.username ?? '-'}" '
            'pada "${result.examTitle ?? 'Ujian'}" akan dihapus permanen.\n\n'
            'Data ini tidak bisa dikembalikan. Lanjutkan?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Ya, Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _deletingResultId = result.id;
    });

    final service = ref.read(examServiceProvider);
    try {
      await service.deleteAdminResult(result.id);
      ref.invalidate(adminResultsProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hasil ujian berhasil dihapus.')),
      );
    } on ApiError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingResultId = null;
        });
      }
    }
  }

  List<ResultResponse> _applyFilters(List<ResultResponse> results) {
    final classFilter = _selectedClassName?.trim();
    final examFilter = _selectedExamId?.trim();

    return results.where((item) {
      if (classFilter != null && classFilter.isNotEmpty) {
        final className = item.className?.trim() ?? "";
        if (className != classFilter) {
          return false;
        }
      }

      if (examFilter != null && examFilter.isNotEmpty) {
        final examId = item.examId?.trim() ?? "";
        if (examId != examFilter) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<String> _extractClassOptions(List<ResultResponse> results) {
    final values = results
        .map((item) => item.className?.trim() ?? "")
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    values.sort(
        (left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
    return values;
  }

  List<_ExamFilterOption> _extractExamOptions(List<ResultResponse> results) {
    final optionsById = <String, _ExamFilterOption>{};
    for (final item in results) {
      final examId = item.examId?.trim();
      if (examId == null || examId.isEmpty) {
        continue;
      }

      final examTitle = item.examTitle?.trim();
      optionsById[examId] = _ExamFilterOption(
        examId: examId,
        examTitle: (examTitle != null && examTitle.isNotEmpty)
            ? examTitle
            : "Ujian tanpa judul",
      );
    }

    final values = optionsById.values.toList()
      ..sort(
        (left, right) => left.examTitle.toLowerCase().compareTo(
              right.examTitle.toLowerCase(),
            ),
      );
    return values;
  }

  Widget _buildFilterCard({
    required List<ResultResponse> allResults,
    required List<ResultResponse> filteredResults,
  }) {
    final classOptions = _extractClassOptions(allResults);
    final examOptions = _extractExamOptions(allResults);
    final examOptionIds = examOptions.map((item) => item.examId).toSet();

    final selectedClassName =
        classOptions.contains(_selectedClassName) ? _selectedClassName : null;
    final selectedExamId =
        examOptionIds.contains(_selectedExamId) ? _selectedExamId : null;

    if (_selectedClassName != selectedClassName ||
        _selectedExamId != selectedExamId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedClassName = selectedClassName;
          _selectedExamId = selectedExamId;
        });
      });
    }

    return AppCard(
      title: "Filter Hasil",
      subtitle:
          "Menampilkan ${filteredResults.length} dari ${allResults.length} data hasil.",
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: <Widget>[
          SizedBox(
            width: 240,
            child: _buildFilterDropdown(
              label: "Filter Kelas",
              value: selectedClassName,
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text("Semua Kelas"),
                ),
                ...classOptions.map(
                  (className) => DropdownMenuItem<String?>(
                    value: className,
                    child: Text(className),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _selectedClassName = value),
            ),
          ),
          SizedBox(
            width: 280,
            child: _buildFilterDropdown(
              label: "Filter Ujian",
              value: selectedExamId,
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text("Semua Ujian"),
                ),
                ...examOptions.map(
                  (exam) => DropdownMenuItem<String?>(
                    value: exam.examId,
                    child: Text(exam.examTitle),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _selectedExamId = value),
            ),
          ),
          OutlinedButton.icon(
            onPressed: (_selectedClassName == null && _selectedExamId == null)
                ? null
                : () {
                    setState(() {
                      _selectedClassName = null;
                      _selectedExamId = null;
                    });
                  },
            icon: const Icon(Icons.clear_rounded),
            label: const Text("Reset Filter"),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String?>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(adminResultsProvider);
    return AdminLayout(
      title: 'Pantau Hasil Ujian',
      subtitle: 'Pantau nilai dan tingkat risiko peserta ujian.',
      activeSection: AdminSection.results,
      child: resultsAsync.when(
        data: (results) {
          if (results.isEmpty) {
            return ListView(
              children: const <Widget>[
                AppCard(
                  title: 'Belum ada hasil',
                  subtitle: 'Belum ada hasil ujian yang masuk.',
                ),
              ],
            );
          }

          final filteredResults = _applyFilters(results);

          return ListView(
            children: <Widget>[
              _buildFilterCard(
                allResults: results,
                filteredResults: filteredResults,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (filteredResults.isEmpty)
                const AppCard(
                  title: "Data tidak ditemukan",
                  subtitle:
                      "Tidak ada hasil ujian yang cocok dengan filter kelas dan ujian saat ini.",
                ),
              ...filteredResults.map((result) {
                final deleting = _deletingResultId == result.id;
                final className = result.className?.trim().isNotEmpty == true
                    ? result.className!.trim()
                    : "-";
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    title: result.examTitle ?? 'Ujian',
                    subtitle:
                        'Peserta: ${result.username ?? '-'}\nKelas: $className\nNilai: ${result.score}\nRisiko: ${riskLevelLabel(result.riskLevel)}',
                    status: result.subjectName,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: () => _openAnswerReview(result),
                          icon: const Icon(Icons.rule_folder_outlined),
                          label: const Text("Review Jawaban"),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openAudioChunks(result),
                          icon: const Icon(Icons.graphic_eq_rounded),
                          label: const Text('Dengar Rekaman'),
                        ),
                        FilledButton.icon(
                          onPressed:
                              deleting ? null : () => _deleteResult(result),
                          icon: deleting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.delete_outline_rounded),
                          label:
                              Text(deleting ? 'Menghapus...' : 'Hapus Hasil'),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                            foregroundColor:
                                Theme.of(context).colorScheme.onError,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const AppCard(
          title: 'Gagal memuat hasil',
          subtitle: 'Data hasil belum bisa dimuat. Coba lagi sebentar.',
        ),
      ),
    );
  }
}

class _ExamFilterOption {
  const _ExamFilterOption({
    required this.examId,
    required this.examTitle,
  });

  final String examId;
  final String examTitle;
}

enum _AnswerStatus {
  correct,
  wrong,
  unanswered,
}

class _AdminAnswerReviewData {
  const _AdminAnswerReviewData({
    required this.questions,
    required this.answersByQuestionId,
  });

  final List<AdminQuestion> questions;
  final Map<String, AdminAttemptAnswer> answersByQuestionId;
}

class _AdminAnswerReviewDialog extends ConsumerStatefulWidget {
  const _AdminAnswerReviewDialog({required this.result});

  final ResultResponse result;

  @override
  ConsumerState<_AdminAnswerReviewDialog> createState() =>
      _AdminAnswerReviewDialogState();
}

class _AdminAnswerReviewDialogState
    extends ConsumerState<_AdminAnswerReviewDialog> {
  late Future<_AdminAnswerReviewData> _reviewFuture;

  @override
  void initState() {
    super.initState();
    _reviewFuture = _loadReviewData();
  }

  Future<_AdminAnswerReviewData> _loadReviewData() async {
    final service = ref.read(examServiceProvider);
    final answers =
        await service.getAdminAttemptAnswers(widget.result.attemptId);
    final answerMap = <String, AdminAttemptAnswer>{};
    for (final answer in answers) {
      if (answer.questionId.trim().isEmpty) {
        continue;
      }
      answerMap[answer.questionId] = answer;
    }

    final subjectId = widget.result.subjectId?.trim();
    var questions = <AdminQuestion>[];
    if (subjectId != null && subjectId.isNotEmpty) {
      questions = await service.listQuestionsBySubject(subjectId);
    }

    if (questions.isEmpty) {
      questions = answers
          .map((item) => item.question)
          .whereType<AdminQuestion>()
          .toList();
    }

    questions.sort((left, right) {
      final byOrder = left.orderIndex.compareTo(right.orderIndex);
      if (byOrder != 0) {
        return byOrder;
      }
      return left.id.compareTo(right.id);
    });

    return _AdminAnswerReviewData(
      questions: questions,
      answersByQuestionId: answerMap,
    );
  }

  void _reload() {
    setState(() {
      _reviewFuture = _loadReviewData();
    });
  }

  _AnswerStatus _resolveStatus(
      AdminQuestion question, AdminAttemptAnswer? answer) {
    if (answer == null || _isEmptyAnswer(answer.answer)) {
      return _AnswerStatus.unanswered;
    }

    if (answer.isCorrect == true) {
      return _AnswerStatus.correct;
    }
    if (answer.isCorrect == false) {
      return _AnswerStatus.wrong;
    }

    final isCorrect = _isAnswerCorrectFallback(
      question: question,
      answer: answer.answer,
    );
    return isCorrect ? _AnswerStatus.correct : _AnswerStatus.wrong;
  }

  bool _isAnswerCorrectFallback({
    required AdminQuestion question,
    required Object? answer,
  }) {
    final expected = question.correctAnswer;
    if (question.type == QuestionType.single) {
      return (answer?.toString().trim() ?? "") ==
          (expected?.toString().trim() ?? "");
    }

    if (question.type == QuestionType.multi) {
      final expectedValues = parseAnswerValueList(expected)..sort();
      final answerValues = parseAnswerValueList(answer)..sort();
      if (expectedValues.length != answerValues.length) {
        return false;
      }
      for (var i = 0; i < expectedValues.length; i++) {
        if (expectedValues[i] != answerValues[i]) {
          return false;
        }
      }
      return true;
    }

    final normalizedAnswer = _normalizeForCompare(answer);
    final normalizedExpected = _normalizeForCompare(expected);
    return jsonEncode(normalizedAnswer) == jsonEncode(normalizedExpected);
  }

  Object? _normalizeForCompare(Object? value) {
    if (value is List<dynamic>) {
      final normalized = value.map(_normalizeForCompare).toList()
        ..sort((left, right) => jsonEncode(left).compareTo(jsonEncode(right)));
      return normalized;
    }
    if (value is Map<String, dynamic>) {
      final sortedKeys = value.keys.toList()..sort();
      return <String, dynamic>{
        for (final key in sortedKeys) key: _normalizeForCompare(value[key]),
      };
    }
    return value;
  }

  bool _isEmptyAnswer(Object? value) {
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

  String _formatAnswerValue(AdminQuestion question, Object? value) {
    if (_isEmptyAnswer(value)) {
      return "-";
    }

    final optionLabels = <String, String>{
      for (final option in parseAdminChoiceOptions(question.options))
        option.value: option.label,
    };

    if (question.type == QuestionType.single) {
      final raw = value?.toString().trim() ?? "";
      if (raw.isEmpty) {
        return "-";
      }
      return _formatOptionLabel(raw, optionLabels);
    }

    if (question.type == QuestionType.multi) {
      final values = parseAnswerValueList(value);
      if (values.isEmpty) {
        return "-";
      }
      return values
          .map((item) => _formatOptionLabel(item, optionLabels))
          .join(", ");
    }

    return _formatRawValue(value);
  }

  String _formatOptionLabel(String value, Map<String, String> optionLabels) {
    final label = optionLabels[value]?.trim();
    if (label == null || label.isEmpty) {
      return value;
    }
    return "$value ($label)";
  }

  String _formatRawValue(Object? value) {
    if (value == null) {
      return "-";
    }
    if (value is String) {
      return value.trim().isEmpty ? "-" : value.trim();
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    try {
      const encoder = JsonEncoder.withIndent("  ");
      return encoder.convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  String _statusLabel(_AnswerStatus status) {
    switch (status) {
      case _AnswerStatus.correct:
        return "Benar";
      case _AnswerStatus.wrong:
        return "Salah";
      case _AnswerStatus.unanswered:
        return "Tidak Dijawab";
    }
  }

  Color _statusColor(BuildContext context, _AnswerStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case _AnswerStatus.correct:
        return Colors.green.shade700;
      case _AnswerStatus.wrong:
        return colorScheme.error;
      case _AnswerStatus.unanswered:
        return Colors.orange.shade700;
    }
  }

  Widget _buildAnswerLine({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        SelectableText(value),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxDialogContentHeight = MediaQuery.sizeOf(context).height * 0.65;
    return AlertDialog(
      title: const Text("Review Jawaban Peserta"),
      content: SizedBox(
        width: 820,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxDialogContentHeight),
          child: FutureBuilder<_AdminAnswerReviewData>(
            future: _reviewFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "Gagal memuat review jawaban: ${snapshot.error}",
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text("Coba Lagi"),
                    ),
                  ],
                );
              }

              final data = snapshot.data;
              if (data == null || data.questions.isEmpty) {
                return const Center(
                  child: Text(
                      "Data jawaban/soal belum tersedia untuk attempt ini."),
                );
              }

              return ListView.separated(
                itemCount: data.questions.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final className =
                        widget.result.className?.trim().isNotEmpty == true
                            ? widget.result.className!.trim()
                            : "-";
                    return AppCard(
                      title: widget.result.examTitle ?? "Ujian",
                      subtitle:
                          "Peserta: ${widget.result.username ?? '-'}\nKelas: $className\nNilai: ${widget.result.score} | Benar: ${widget.result.correct} | Salah: ${widget.result.wrong}",
                    );
                  }

                  final question = data.questions[index - 1];
                  final answer = data.answersByQuestionId[question.id];
                  final status = _resolveStatus(question, answer);
                  final statusColor = _statusColor(context, status);

                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.45)),
                      color: statusColor.withValues(alpha: 0.08),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                "Soal $index",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: statusColor.withValues(alpha: 0.18),
                              ),
                              child: Text(
                                _statusLabel(status),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SelectableText(question.text),
                        const SizedBox(height: AppSpacing.sm),
                        _buildAnswerLine(
                          label: "Jawaban Peserta",
                          value: _formatAnswerValue(question, answer?.answer),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _buildAnswerLine(
                          label: "Kunci Jawaban",
                          value: _formatAnswerValue(
                              question, question.correctAnswer),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _reload,
          child: const Text("Refresh"),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Tutup"),
        ),
      ],
    );
  }
}

class _AdminAudioChunkDialog extends ConsumerStatefulWidget {
  const _AdminAudioChunkDialog({required this.result});

  final ResultResponse result;

  @override
  ConsumerState<_AdminAudioChunkDialog> createState() =>
      _AdminAudioChunkDialogState();
}

class _AdminAudioChunkDialogState
    extends ConsumerState<_AdminAudioChunkDialog> {
  late Future<List<AttemptAudioChunk>> _chunksFuture;
  final AudioPlayer _player = AudioPlayer();
  final Map<String, String> _cachedChunkFiles = <String, String>{};
  List<AttemptAudioChunk> _playbackQueue = const <AttemptAudioChunk>[];
  bool _isLoadingPlayback = false;
  bool _isSequencePlaybackActive = false;
  bool _isAdvancingPlayback = false;
  int _playbackIndex = -1;

  @override
  void initState() {
    super.initState();
    _chunksFuture = _fetchChunks();
    _player.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      if (!_isSequencePlaybackActive) {
        return;
      }
      unawaited(_playNextChunkInQueue());
    });
  }

  @override
  void dispose() {
    unawaited(_player.stop());
    _player.dispose();
    for (final entry in _cachedChunkFiles.values) {
      final file = File(entry);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
    super.dispose();
  }

  Future<List<AttemptAudioChunk>> _fetchChunks() {
    return ref
        .read(examServiceProvider)
        .getAdminAttemptAudioChunks(widget.result.attemptId);
  }

  void _reload() {
    unawaited(_stopPlaybackSequence());
    setState(() {
      _chunksFuture = _fetchChunks();
    });
  }

  List<AttemptAudioChunk> _orderedChunks(List<AttemptAudioChunk> chunks) {
    final ordered = List<AttemptAudioChunk>.from(chunks);
    ordered.sort((left, right) => left.chunkIndex.compareTo(right.chunkIndex));
    return ordered;
  }

  Future<void> _playOrStopSequence(List<AttemptAudioChunk> chunks) async {
    if (_isLoadingPlayback) {
      return;
    }

    if (_isSequencePlaybackActive) {
      await _stopPlaybackSequence();
      return;
    }

    final orderedChunks = _orderedChunks(chunks);
    if (orderedChunks.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingPlayback = true;
    });

    try {
      await _prepareChunkFiles(orderedChunks);
      if (!mounted) {
        return;
      }

      await _player.stop();
      if (!mounted) {
        return;
      }

      setState(() {
        _playbackQueue = orderedChunks;
        _isSequencePlaybackActive = true;
        _playbackIndex = 0;
      });

      await _playChunkFromQueue(0);
    } on ApiError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      await _stopPlaybackSequence();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memutar rekaman audio.')),
      );
      await _stopPlaybackSequence();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPlayback = false;
        });
      }
    }
  }

  Future<void> _prepareChunkFiles(List<AttemptAudioChunk> chunks) async {
    for (final chunk in chunks) {
      await _resolveLocalChunkFile(chunk);
    }
  }

  Future<void> _playChunkFromQueue(int index) async {
    if (index < 0 || index >= _playbackQueue.length) {
      return;
    }

    final chunk = _playbackQueue[index];
    final localPath = await _resolveLocalChunkFile(chunk);
    await _player.play(DeviceFileSource(localPath));

    if (!mounted) {
      return;
    }

    setState(() {
      _playbackIndex = index;
    });
  }

  Future<void> _playNextChunkInQueue() async {
    if (!_isSequencePlaybackActive || _isAdvancingPlayback) {
      return;
    }

    _isAdvancingPlayback = true;
    try {
      final nextIndex = _playbackIndex + 1;
      if (nextIndex >= _playbackQueue.length) {
        await _stopPlaybackSequence();
        return;
      }

      await _playChunkFromQueue(nextIndex);
    } on ApiError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
      await _stopPlaybackSequence();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memutar rekaman audio.')),
        );
      }
      await _stopPlaybackSequence();
    } finally {
      _isAdvancingPlayback = false;
    }
  }

  Future<void> _stopPlaybackSequence() async {
    _isAdvancingPlayback = false;
    await _player.stop();
    if (!mounted) {
      return;
    }

    setState(() {
      _isSequencePlaybackActive = false;
      _playbackQueue = const <AttemptAudioChunk>[];
      _playbackIndex = -1;
    });
  }

  Future<String> _resolveLocalChunkFile(AttemptAudioChunk chunk) async {
    final cachedPath = _cachedChunkFiles[chunk.id];
    if (cachedPath != null) {
      final cachedFile = File(cachedPath);
      if (await cachedFile.exists()) {
        return cachedPath;
      }
    }

    final bytes = await ref
        .read(examServiceProvider)
        .downloadAdminAudioChunkFile(chunk.id);
    final tempDir = await getTemporaryDirectory();
    final extension = _resolveAudioExtension(chunk.mimeType);
    final filePath =
        '${tempDir.path}${Platform.pathSeparator}chunk_${chunk.id}.$extension';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    _cachedChunkFiles[chunk.id] = filePath;
    return filePath;
  }

  String _resolveAudioExtension(String mimeType) {
    final normalized = mimeType.toLowerCase();
    if (normalized.contains('webm')) {
      return 'webm';
    }
    if (normalized.contains('ogg')) {
      return 'ogg';
    }
    if (normalized.contains('wav')) {
      return 'wav';
    }
    if (normalized.contains('mpeg') || normalized.contains('mp3')) {
      return 'mp3';
    }
    if (normalized.contains('aac')) {
      return 'aac';
    }
    if (normalized.contains('mp4')) {
      return 'mp4';
    }
    if (normalized.contains('m4a')) {
      return 'm4a';
    }
    return 'm4a';
  }

  int _resolveChunkDurationSeconds(AttemptAudioChunk chunk) {
    final startedAt = chunk.startedAt;
    final endedAt = chunk.endedAt;
    if (startedAt == null || endedAt == null) {
      return 0;
    }
    final seconds = endedAt.difference(startedAt).inSeconds;
    return seconds > 0 ? seconds : 0;
  }

  String _formatTotalDuration(List<AttemptAudioChunk> chunks) {
    final totalSeconds = chunks.fold<int>(
      0,
      (total, chunk) => total + _resolveChunkDurationSeconds(chunk),
    );
    if (totalSeconds <= 0) {
      return '-';
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final parts = <String>[];
    if (hours > 0) {
      parts.add('${hours}j');
    }
    if (minutes > 0 || hours > 0) {
      parts.add('${minutes}m');
    }
    parts.add('${seconds}dtk');
    return parts.join(' ');
  }

  String _formatCaptureWindow(List<AttemptAudioChunk> chunks) {
    if (chunks.isEmpty) {
      return '-';
    }

    final first = chunks.first;
    final last = chunks.last;
    final startedAt = (first.startedAt ?? first.createdAt).toLocal();
    final endedAt = (last.endedAt ?? last.createdAt).toLocal();
    return '${_formatChunkTime(startedAt)} - ${_formatChunkTime(endedAt)}';
  }

  String _formatChunkTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String _formatByteSize(int byteSize) {
    if (byteSize < 1024) {
      return '$byteSize B';
    }
    if (byteSize < 1024 * 1024) {
      return '${(byteSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(byteSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Widget _buildSummaryLine({
    required BuildContext context,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxDialogContentHeight = MediaQuery.sizeOf(context).height * 0.6;

    return AlertDialog(
      title: const Text('Rekaman Pengerjaan'),
      content: SizedBox(
        width: 640,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxDialogContentHeight),
          child: FutureBuilder<List<AttemptAudioChunk>>(
            future: _chunksFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Gagal memuat rekaman: ${snapshot.error}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed: _reload,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                );
              }

              final chunks = _orderedChunks(
                snapshot.data ?? const <AttemptAudioChunk>[],
              );
              if (chunks.isEmpty) {
                return const SizedBox(
                  height: 180,
                  child: Center(
                    child: Text('Belum ada rekaman audio untuk attempt ini.'),
                  ),
                );
              }

              final totalByteSize = chunks.fold<int>(
                0,
                (total, chunk) => total + chunk.byteSize,
              );
              final activeChunkNumber =
                  _playbackIndex >= 0 ? _playbackIndex + 1 : 1;
              final playbackStatusText = _isLoadingPlayback
                  ? 'Menyiapkan rekaman, mohon tunggu...'
                  : _isSequencePlaybackActive
                      ? 'Sedang memutar bagian $activeChunkNumber dari ${chunks.length}.'
                      : 'Semua segmen diputar berurutan sebagai satu rekaman.';

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Peserta: ${widget.result.username ?? '-'} | Ujian: ${widget.result.examTitle ?? '-'}',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildSummaryLine(
                            context: context,
                            label: 'Durasi Total',
                            value: _formatTotalDuration(chunks),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          _buildSummaryLine(
                            context: context,
                            label: 'Rentang Waktu',
                            value: _formatCaptureWindow(chunks),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          _buildSummaryLine(
                            context: context,
                            label: 'Segmen Internal',
                            value: '${chunks.length} file',
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          _buildSummaryLine(
                            context: context,
                            label: 'Total Ukuran',
                            value: _formatByteSize(totalByteSize),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: _isLoadingPlayback
                          ? null
                          : () => _playOrStopSequence(chunks),
                      icon: _isLoadingPlayback
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              _isSequencePlaybackActive
                                  ? Icons.stop_circle_outlined
                                  : Icons.play_circle_fill_rounded,
                            ),
                      label: Text(
                        _isSequencePlaybackActive
                            ? 'Stop Rekaman'
                            : 'Play Rekaman',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(playbackStatusText),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _reload,
          child: const Text('Refresh'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
