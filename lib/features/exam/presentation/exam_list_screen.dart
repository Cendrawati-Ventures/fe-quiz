import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_button.dart';
import '../../auth/model/auth_user.dart';
import '../../auth/state/auth_provider.dart';
import '../model/exam_models.dart';
import '../state/exam_state.dart';

class _StudentIdentity {
  const _StudentIdentity({
    required this.name,
    required this.className,
    required this.rollNumber,
  });

  final String name;
  final String className;
  final String rollNumber;

  bool get isComplete {
    return name.trim().isNotEmpty &&
        className.trim().isNotEmpty &&
        rollNumber.trim().isNotEmpty;
  }

  _StudentIdentity copyWith({
    String? name,
    String? className,
    String? rollNumber,
  }) {
    return _StudentIdentity(
      name: name ?? this.name,
      className: className ?? this.className,
      rollNumber: rollNumber ?? this.rollNumber,
    );
  }
}

class _SubjectQuestionStat {
  const _SubjectQuestionStat({
    required this.questionCount,
    required this.totalWeight,
  });

  final int questionCount;
  final num totalWeight;
}

final subjectQuestionStatsProvider =
    FutureProvider<Map<String, _SubjectQuestionStat>>((ref) async {
  final subjects = await ref.watch(subjectListProvider.future);
  final service = ref.watch(examServiceProvider);

  final rows = await Future.wait(
    subjects.map((subject) async {
      final questions = await service.listQuestionsBySubject(subject.id);
      final totalWeight = questions.fold<num>(
        0,
        (total, question) => total + question.weight,
      );
      return MapEntry(
        subject.id,
        _SubjectQuestionStat(
          questionCount: questions.length,
          totalWeight: totalWeight,
        ),
      );
    }),
  );

  return Map<String, _SubjectQuestionStat>.fromEntries(rows);
});

class ExamListScreen extends ConsumerStatefulWidget {
  const ExamListScreen({super.key});

  @override
  ConsumerState<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends ConsumerState<ExamListScreen> {
  _StudentIdentity _identity = const _StudentIdentity(
    name: '',
    className: '',
    rollNumber: '',
  );
  bool _identitySeeded = false;
  String? _selectedExamId;
  String? _selectedSubjectId;
  bool _isStartingExam = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final username = user?.username ?? 'siswa';

    if (!_identitySeeded) {
      _identitySeeded = true;
      _identity = _identity.copyWith(name: _displayNameFromUsername(username));
    }

    final examsAsync = ref.watch(examListProvider);
    final subjectsAsync = ref.watch(subjectListProvider);
    final resultsAsync = ref.watch(myResultsProvider);
    final statsAsync = ref.watch(subjectQuestionStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFE1E7D0),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _StudentTopBar(
              username: username,
              onLogout: _confirmLogout,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshAll,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.lg,
                  ),
                  children: <Widget>[
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: _buildBody(
                          context: context,
                          user: user,
                          examsAsync: examsAsync,
                          subjectsAsync: subjectsAsync,
                          resultsAsync: resultsAsync,
                          statsAsync: statsAsync,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required AuthUser? user,
    required AsyncValue<List<ApiExam>> examsAsync,
    required AsyncValue<List<ApiSubject>> subjectsAsync,
    required AsyncValue<List<ResultResponse>> resultsAsync,
    required AsyncValue<Map<String, _SubjectQuestionStat>> statsAsync,
  }) {
    final examsError = examsAsync.hasError ? examsAsync.error : null;
    if (examsError != null) {
      return _buildCriticalErrorCard(
        title: 'Data ujian belum bisa dimuat',
        subtitle: examsError.toString(),
      );
    }

    final subjectsError = subjectsAsync.hasError ? subjectsAsync.error : null;
    if (subjectsError != null) {
      return _buildCriticalErrorCard(
        title: 'Data mata pelajaran belum bisa dimuat',
        subtitle: subjectsError.toString(),
      );
    }

    final examsLoading = examsAsync.isLoading;
    final subjectsLoading = subjectsAsync.isLoading;

    if (examsLoading || subjectsLoading) {
      return _buildLoadingCard();
    }

    final exams = examsAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <ApiExam>[],
    );
    final subjects = subjectsAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <ApiSubject>[],
    );
    final results = resultsAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <ResultResponse>[],
    );
    final stats = statsAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <String, _SubjectQuestionStat>{},
    );

    final resultWarning = resultsAsync.hasError ? resultsAsync.error : null;
    final statWarning = statsAsync.hasError ? statsAsync.error : null;

    if (exams.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildIdentityCard(),
          const SizedBox(height: AppSpacing.md),
          _buildCriticalErrorCard(
            title: 'Belum ada ujian aktif',
            subtitle:
                'Guru/admin perlu membuat dan mempublikasikan ujian lebih dulu agar tampil di akun siswa.',
          ),
        ],
      );
    }

    if (subjects.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildIdentityCard(),
          const SizedBox(height: AppSpacing.md),
          _buildCriticalErrorCard(
            title: 'Mata pelajaran belum tersedia',
            subtitle:
                'Guru/admin belum menambahkan mata pelajaran. Hubungi admin untuk melengkapi data.',
          ),
        ],
      );
    }

    final selectedExamId = _resolveExamId(exams);
    final selectedSubjectId = _resolveSubjectId(subjects);

    final selectedExam = exams.firstWhere((item) => item.id == selectedExamId);
    final selectedSubject =
        subjects.firstWhere((item) => item.id == selectedSubjectId);

    final selectedStat = stats[selectedSubject.id] ??
        const _SubjectQuestionStat(questionCount: 0, totalWeight: 0);
    final selectedAttempts = _attemptCount(
      results: results,
      subject: selectedSubject,
      exam: selectedExam,
    );

    final canStart = _canStartSubject(
      attemptsUsed: selectedAttempts,
      attemptLimit: selectedSubject.attemptLimit,
      stat: selectedStat,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildIdentityCard(),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: const Color(0xFFF6F5EF),
            border: Border.all(color: const Color(0xFFC9D2BF)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 880;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _sectionTag('LANGKAH 1'),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Selamat datang, ${user?.username ?? 'siswa'}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3F341F),
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Pilih mata pelajaran yang ingin kamu kerjakan dan baca ringkasannya sebelum menekan Mulai Ujian.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6C624F),
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (exams.length > 1) ...<Widget>[
                    DropdownButtonFormField<String>(
                      initialValue: selectedExamId,
                      decoration: const InputDecoration(
                        labelText: 'Pilih Ujian Aktif',
                      ),
                      items: exams
                          .map(
                            (exam) => DropdownMenuItem<String>(
                              value: exam.id,
                              child: Text(exam.title),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedExamId = value;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Text(
                    'Daftar Mata Pelajaran',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3F341F),
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (isCompact)
                    _buildMobileSubjectList(
                      subjects: subjects,
                      selectedSubjectId: selectedSubjectId,
                      selectedExam: selectedExam,
                      results: results,
                      stats: stats,
                    )
                  else
                    _buildDesktopSubjectTable(
                      subjects: subjects,
                      selectedSubjectId: selectedSubjectId,
                      selectedExam: selectedExam,
                      results: results,
                      stats: stats,
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildSelectedSubjectPills(
                    subject: selectedSubject,
                    stat: selectedStat,
                    attemptsUsed: selectedAttempts,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Mulai Ujian',
                    loading: _isStartingExam,
                    disabled: !canStart,
                    onPressed: () => _startExam(
                      exam: selectedExam,
                      subject: selectedSubject,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _subjectStatusText(
                      subject: selectedSubject,
                      stat: selectedStat,
                      attemptsUsed: selectedAttempts,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: canStart
                              ? const Color(0xFF1B7A42)
                              : const Color(0xFF8A3F28),
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/result'),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('Export Nilai'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF148B4A),
                      side: const BorderSide(color: Color(0xFF95CAA9)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  if (resultWarning != null || statWarning != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFFFF2D8),
                        border: Border.all(color: const Color(0xFFE9C886)),
                      ),
                      child: Text(
                        'Sebagian ringkasan belum bisa dimuat. Tarik layar ke bawah untuk memuat ulang data siswa.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF7D5A12),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIdentityCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFFF6F5EF),
        border: Border.all(color: const Color(0xFFC9D2BF)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _sectionTag('DATA ANAK'),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Nama, Kelas & No Absen',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3F341F),
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Pastikan ketiga data ini benar sebelum mulai mengerjakan soal.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6C624F),
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (compact) ...<Widget>[
                _identityField(label: 'NAMA', value: _identity.name),
                const SizedBox(height: AppSpacing.sm),
                _identityField(label: 'KELAS', value: _identity.className),
                const SizedBox(height: AppSpacing.sm),
                _identityField(label: 'NO ABSEN', value: _identity.rollNumber),
              ] else
                Row(
                  children: <Widget>[
                    Expanded(
                      child:
                          _identityField(label: 'NAMA', value: _identity.name),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _identityField(
                        label: 'KELAS',
                        value: _identity.className,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _identityField(
                        label: 'NO ABSEN',
                        value: _identity.rollNumber,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: _showIdentityDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF148B4A),
                      side: const BorderSide(color: Color(0xFF95CAA9)),
                    ),
                    child: const Text('Isi / Ubah Data'),
                  ),
                  Text(
                    _identity.isComplete
                        ? 'Data sudah lengkap. Kamu siap mulai ujian.'
                        : 'Lengkapi dulu nama, kelas, dan no absen.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _identity.isComplete
                              ? const Color(0xFF1B7A42)
                              : const Color(0xFF8A3F28),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDesktopSubjectTable({
    required List<ApiSubject> subjects,
    required String selectedSubjectId,
    required ApiExam selectedExam,
    required List<ResultResponse> results,
    required Map<String, _SubjectQuestionStat> stats,
  }) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelLarge?.copyWith(
      color: const Color(0xFF3F341F),
      fontWeight: FontWeight.w700,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC9D2BF)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFE4E9D7),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                    flex: 17,
                    child: Text('Mata Pelajaran', style: headerStyle)),
                Expanded(flex: 9, child: Text('Durasi', style: headerStyle)),
                Expanded(
                  flex: 13,
                  child: Text('Batas Pengulangan', style: headerStyle),
                ),
                Expanded(
                    flex: 12,
                    child: Text('Pengerjaan Saya', style: headerStyle)),
                Expanded(
                    flex: 10, child: Text('Soal Tersedia', style: headerStyle)),
                Expanded(
                    flex: 12, child: Text('Bobot Soal', style: headerStyle)),
                Expanded(flex: 10, child: Text('Aksi', style: headerStyle)),
              ],
            ),
          ),
          ...subjects.map((subject) {
            final stat = stats[subject.id] ??
                const _SubjectQuestionStat(questionCount: 0, totalWeight: 0);
            final attempts = _attemptCount(
              results: results,
              subject: subject,
              exam: selectedExam,
            );
            final isSelected = subject.id == selectedSubjectId;
            final canStart = _canStartSubject(
              attemptsUsed: attempts,
              attemptLimit: subject.attemptLimit,
              stat: stat,
            );

            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFF1E5CC)
                    : const Color(0xFFF9F8F2),
                border: const Border(
                  top: BorderSide(color: Color(0xFFD8DFCE)),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(flex: 17, child: Text(subject.name)),
                  Expanded(
                    flex: 9,
                    child: Text('${subject.durationMinutes} menit'),
                  ),
                  Expanded(flex: 13, child: Text('${subject.attemptLimit}x')),
                  Expanded(
                    flex: 12,
                    child: Text('$attempts/${subject.attemptLimit}'),
                  ),
                  Expanded(flex: 10, child: Text('${stat.questionCount}')),
                  Expanded(
                    flex: 12,
                    child: Text('${_formatWeight(stat.totalWeight)}/100'),
                  ),
                  Expanded(
                    flex: 10,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _selectedSubjectId = subject.id;
                          });
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: canStart
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF9CA3AF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                        ),
                        child: const Text('Pilih'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMobileSubjectList({
    required List<ApiSubject> subjects,
    required String selectedSubjectId,
    required ApiExam selectedExam,
    required List<ResultResponse> results,
    required Map<String, _SubjectQuestionStat> stats,
  }) {
    return Column(
      children: subjects.map((subject) {
        final stat = stats[subject.id] ??
            const _SubjectQuestionStat(questionCount: 0, totalWeight: 0);
        final attempts = _attemptCount(
          results: results,
          subject: subject,
          exam: selectedExam,
        );
        final selected = subject.id == selectedSubjectId;
        final canStart = _canStartSubject(
          attemptsUsed: attempts,
          attemptLimit: subject.attemptLimit,
          stat: stat,
        );

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected ? const Color(0xFF95CAA9) : const Color(0xFFC9D2BF),
            ),
            color: selected ? const Color(0xFFF1E5CC) : const Color(0xFFF9F8F2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      subject.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _selectedSubjectId = subject.id;
                      });
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: canStart
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF9CA3AF),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Pilih'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Durasi: ${subject.durationMinutes} menit - Batas: ${subject.attemptLimit}x',
              ),
              Text('Pengerjaan: $attempts/${subject.attemptLimit}'),
              Text('Soal tersedia: ${stat.questionCount}'),
              Text('Bobot: ${_formatWeight(stat.totalWeight)}/100'),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectedSubjectPills({
    required ApiSubject subject,
    required _SubjectQuestionStat stat,
    required int attemptsUsed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFE8EDF6),
        border: Border.all(color: const Color(0xFFBDD0F5)),
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: <Widget>[
          _InfoPill(label: subject.name, background: const Color(0xFFE8D9BC)),
          _InfoPill(label: '${subject.durationMinutes} menit'),
          _InfoPill(label: 'Batas ${subject.attemptLimit}x'),
          _InfoPill(label: 'Percobaan $attemptsUsed/${subject.attemptLimit}'),
          _InfoPill(label: 'Soal ${stat.questionCount}'),
          _InfoPill(label: 'Bobot ${_formatWeight(stat.totalWeight)}/100'),
        ],
      ),
    );
  }

  Widget _identityField({required String label, required String value}) {
    final showValue = value.trim().isEmpty ? '-' : value.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$label :',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF6A624D),
                letterSpacing: 1,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          showValue,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3F341F),
              ),
        ),
      ],
    );
  }

  Widget _sectionTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFFDBEBD6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF1D8A4D),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
      ),
    );
  }

  Widget _buildCriticalErrorCard({
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFFFF4F4),
        border: Border.all(color: const Color(0xFFE4B4B4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Muat Ulang',
            onPressed: _refreshAll,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFF6F5EF),
        border: Border.all(color: const Color(0xFFC9D2BF)),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _refreshAll() async {
    ref.invalidate(examListProvider);
    ref.invalidate(subjectListProvider);
    ref.invalidate(myResultsProvider);
    ref.invalidate(subjectQuestionStatsProvider);

    try {
      await ref.read(examListProvider.future);
    } catch (_) {}
    try {
      await ref.read(subjectListProvider.future);
    } catch (_) {}
    try {
      await ref.read(myResultsProvider.future);
    } catch (_) {}
  }

  String _resolveExamId(List<ApiExam> exams) {
    final selectedId = _selectedExamId;
    if (selectedId != null) {
      for (final item in exams) {
        if (item.id == selectedId) {
          return selectedId;
        }
      }
    }
    return exams.first.id;
  }

  String _resolveSubjectId(List<ApiSubject> subjects) {
    final selectedId = _selectedSubjectId;
    if (selectedId != null) {
      for (final item in subjects) {
        if (item.id == selectedId) {
          return selectedId;
        }
      }
    }
    return subjects.first.id;
  }

  int _attemptCount({
    required List<ResultResponse> results,
    required ApiSubject subject,
    required ApiExam exam,
  }) {
    final targetSubject = subject.name.trim().toLowerCase();
    final targetExam = exam.title.trim().toLowerCase();

    var count = 0;
    for (final item in results) {
      final subjectName = (item.subjectName ?? '').trim().toLowerCase();
      if (subjectName != targetSubject) {
        continue;
      }
      final examName = (item.examTitle ?? '').trim().toLowerCase();
      if (examName.isNotEmpty && examName != targetExam) {
        continue;
      }
      count += 1;
    }
    return count;
  }

  bool _canStartSubject({
    required int attemptsUsed,
    required int attemptLimit,
    required _SubjectQuestionStat stat,
  }) {
    if (!_identity.isComplete) {
      return false;
    }
    if (attemptsUsed >= attemptLimit) {
      return false;
    }
    if (stat.questionCount <= 0) {
      return false;
    }
    return (stat.totalWeight - 100).abs() < 0.001;
  }

  String _subjectStatusText({
    required ApiSubject subject,
    required _SubjectQuestionStat stat,
    required int attemptsUsed,
  }) {
    if (!_identity.isComplete) {
      return 'Lengkapi data anak dulu sebelum mulai ujian.';
    }
    if (attemptsUsed >= subject.attemptLimit) {
      return 'Batas percobaan untuk ${subject.name} sudah habis (${subject.attemptLimit}x).';
    }
    if (stat.questionCount <= 0) {
      return 'Mata pelajaran ${subject.name} belum memiliki soal.';
    }
    if ((stat.totalWeight - 100).abs() >= 0.001) {
      return 'Bobot soal ${subject.name} baru ${_formatWeight(stat.totalWeight)}/100. Hubungi guru/admin.';
    }
    return 'Mata pelajaran ${subject.name} siap. Percobaan kamu $attemptsUsed/${subject.attemptLimit}. Tekan Mulai Ujian saat siap.';
  }

  String _formatWeight(num value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.001) {
      return '${rounded.toInt()}';
    }
    return value.toStringAsFixed(1);
  }

  Future<void> _startExam({
    required ApiExam exam,
    required ApiSubject subject,
  }) async {
    if (_isStartingExam) {
      return;
    }

    setState(() {
      _isStartingExam = true;
    });

    await ref.read(examSessionProvider.notifier).startAttempt(
          exam: exam,
          subject: subject,
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _isStartingExam = false;
    });

    final session = ref.read(examSessionProvider);
    if (session.hasActiveAttempt) {
      context.go('/exam/session');
      return;
    }

    final message = session.errorMessage ?? 'Ujian belum bisa dimulai.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showIdentityDialog() async {
    final updated = await showDialog<_StudentIdentity>(
      context: context,
      builder: (context) => _StudentIdentityDialog(initial: _identity),
    );

    if (updated != null) {
      setState(() {
        _identity = updated;
      });
    }
  }

  String _displayNameFromUsername(String username) {
    final cleaned = username.trim();
    if (cleaned.isEmpty) {
      return '';
    }

    final words = cleaned
        .replaceAll(RegExp(r'[_\-.]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();

    if (words.isEmpty) {
      return cleaned;
    }

    final transformed = words.map((word) {
      final lower = word.toLowerCase();
      final first = lower.substring(0, 1).toUpperCase();
      final tail = lower.length > 1 ? lower.substring(1) : '';
      return '$first$tail';
    }).toList();

    return transformed.join(' ');
  }

  void _confirmLogout() async {
    final confirmed = await _showLogoutConfirmationDialog(
      context,
      roleLabel: 'siswa',
    );
    if (!mounted || !confirmed) {
      return;
    }
    ref.read(authProvider.notifier).logout();
  }
}

class _StudentTopBar extends StatelessWidget {
  const _StudentTopBar({
    required this.username,
    required this.onLogout,
  });

  final String username;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF19743F), Color(0xFF0F6A39)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x22104F2A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: compact ? 54 : 62,
                    height: compact ? 54 : 62,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'RUANG CERITA',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: const Color(0xFFD4F1D8),
                                  letterSpacing: 3,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      Text(
                        'Mode Ujian Siswa',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        'Belajar rapi, kerjakan ujian dengan tenang.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFE6F8E8),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    child: Text(
                      username,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: onLogout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                    ),
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StudentIdentityDialog extends StatefulWidget {
  const _StudentIdentityDialog({required this.initial});

  final _StudentIdentity initial;

  @override
  State<_StudentIdentityDialog> createState() => _StudentIdentityDialogState();
}

class _StudentIdentityDialogState extends State<_StudentIdentityDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _classController;
  late final TextEditingController _rollController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial.name);
    _classController = TextEditingController(text: widget.initial.className);
    _rollController = TextEditingController(text: widget.initial.rollNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _classController.dispose();
    _rollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Isi Data Siswa'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Nama wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _classController,
                decoration: const InputDecoration(labelText: 'Kelas'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Kelas wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _rollController,
                decoration: const InputDecoration(labelText: 'No Absen'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'No absen wajib diisi';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }
            Navigator.of(context).pop(
              widget.initial.copyWith(
                name: _nameController.text.trim(),
                className: _classController.text.trim(),
                rollNumber: _rollController.text.trim(),
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

Future<bool> _showLogoutConfirmationDialog(
  BuildContext context, {
  required String roleLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: Text('Apakah kamu yakin ingin keluar dari akun $roleLabel?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, Keluar'),
          ),
        ],
      );
    },
  );

  return result ?? false;
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    this.background,
  });

  final String label;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: background ?? const Color(0xFF16A34A),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
