import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_button.dart';
import '../../auth/model/auth_user.dart';
import '../../auth/state/auth_provider.dart';
import '../model/exam_models.dart';
import '../service/classroom_service.dart';
import '../state/exam_state.dart';
import '../state/student_class_scope_state.dart';
import 'widgets/student_layout.dart';

class _StudentIdentity {
  const _StudentIdentity({
    required this.name,
    required this.classId,
    required this.className,
    required this.rollNumber,
  });

  final String name;
  final String classId;
  final String className;
  final String rollNumber;

  bool get hasEditableFieldsComplete {
    return name.trim().isNotEmpty && rollNumber.trim().isNotEmpty;
  }

  bool get hasAssignedClass =>
      classId.trim().isNotEmpty || className.trim().isNotEmpty;

  bool get isReadyForExam => hasEditableFieldsComplete && hasAssignedClass;

  _StudentIdentity copyWith({
    String? name,
    String? classId,
    String? className,
    String? rollNumber,
  }) {
    return _StudentIdentity(
      name: name ?? this.name,
      classId: classId ?? this.classId,
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

final studentScopedSubjectListProvider =
    FutureProvider<List<ApiSubject>>((ref) async {
  final service = ref.watch(examServiceProvider);
  final selectedClassId = ref.watch(effectiveStudentClassIdProvider);
  return service.listSubjects(classId: selectedClassId);
});

final subjectQuestionStatsProvider =
    FutureProvider<Map<String, _SubjectQuestionStat>>((ref) async {
  final subjects = await ref.watch(studentScopedSubjectListProvider.future);
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
  bool _identityPromptScheduled = false;
  bool _isIdentityDialogOpen = false;
  String? _startingSubjectId;
  bool _hasTriggeredInitialRefresh = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasTriggeredInitialRefresh) {
        return;
      }
      _hasTriggeredInitialRefresh = true;
      _refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final identity = _identityFromUser(user);
    final isSavingIdentity =
        authState.status == AuthStatus.authenticated && authState.isLoading;
    _scheduleIdentityPromptIfNeeded(
      user: user,
      identity: identity,
      isSavingIdentity: isSavingIdentity,
    );

    final subjectsAsync = ref.watch(studentScopedSubjectListProvider);
    final standbyAsync = ref.watch(proctoringStandbyStatusProvider);
    final myClassOptionsAsync = ref.watch(myClassOptionsProvider);
    final resultsAsync = ref.watch(myResultsProvider);
    final statsAsync = ref.watch(subjectQuestionStatsProvider);
    final standbyStatus = standbyAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final isStandbyActive = standbyStatus?.isActive ?? false;
    final hasSelectableClass = myClassOptionsAsync.maybeWhen(
      data: (items) => items.isNotEmpty,
      orElse: () => false,
    );

    return StudentLayout(
      title: 'Daftar Ujian',
      subtitle: 'Mulai ujian langsung dari card yang tersedia.',
      activeSection: StudentSection.exams,
      contentPadding: EdgeInsets.zero,
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
                  identity: identity,
                  isSavingIdentity: isSavingIdentity,
                  subjectsAsync: subjectsAsync,
                  isStandbyActive: isStandbyActive,
                  hasSelectableClass: hasSelectableClass,
                  resultsAsync: resultsAsync,
                  statsAsync: statsAsync,
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
    required _StudentIdentity identity,
    required bool isSavingIdentity,
    required AsyncValue<List<ApiSubject>> subjectsAsync,
    required bool isStandbyActive,
    required bool hasSelectableClass,
    required AsyncValue<List<ResultResponse>> resultsAsync,
    required AsyncValue<Map<String, _SubjectQuestionStat>> statsAsync,
  }) {
    final hasAssignedClass = identity.hasAssignedClass || hasSelectableClass;
    final subjectsError = subjectsAsync.hasError ? subjectsAsync.error : null;
    if (subjectsError != null) {
      return _buildCriticalErrorCard(
        title: 'Data ujian belum bisa dimuat',
        subtitle: subjectsError.toString(),
      );
    }

    final subjectsLoading = subjectsAsync.isLoading;

    if (subjectsLoading) {
      return _buildLoadingCard();
    }

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

    if (subjects.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildIdentityCard(
            identity: identity,
            hasAssignedClass: hasAssignedClass,
            isSavingIdentity: isSavingIdentity,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildCriticalErrorCard(
            title: 'Ujian belum tersedia',
            subtitle: hasAssignedClass
                ? 'Ujian untuk kelas kamu belum terbuka. Minta admin cek menu Kelas > Kelola Akses Ujian, pastikan soal sudah ada, dan jadwal publish masih aktif.'
                : 'Kelas kamu belum ditetapkan admin, jadi daftar ujian belum bisa ditampilkan.',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildIdentityCard(
          identity: identity,
          hasAssignedClass: hasAssignedClass,
          isSavingIdentity: isSavingIdentity,
        ),
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
                  _sectionTag('UJIAN AKTIF'),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Selamat datang, ${identity.name.trim().isEmpty ? (user?.username ?? 'siswa') : identity.name}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3F341F),
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tekan tombol Mulai pada card ujian yang ingin kamu kerjakan. Setiap mulai ujian akan dikonfirmasi dulu.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6C624F),
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Daftar Ujian',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3F341F),
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (isCompact)
                    _buildExamCards(
                      isIdentityReady: identity.isReadyForExam,
                      hasAssignedClass: hasAssignedClass,
                      isStandbyActive: isStandbyActive,
                      isCompact: isCompact,
                      subjects: subjects,
                      results: results,
                      stats: stats,
                    )
                  else
                    _buildExamCards(
                      isIdentityReady: identity.isReadyForExam,
                      hasAssignedClass: hasAssignedClass,
                      isStandbyActive: isStandbyActive,
                      isCompact: isCompact,
                      subjects: subjects,
                      results: results,
                      stats: stats,
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

  Widget _buildIdentityCard({
    required _StudentIdentity identity,
    required bool hasAssignedClass,
    required bool isSavingIdentity,
  }) {
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
                _identityField(label: 'NAMA', value: identity.name),
                const SizedBox(height: AppSpacing.sm),
                _identityField(label: 'KELAS', value: identity.className),
                const SizedBox(height: AppSpacing.sm),
                _identityField(label: 'NO ABSEN', value: identity.rollNumber),
              ] else
                Row(
                  children: <Widget>[
                    Expanded(
                      child:
                          _identityField(label: 'NAMA', value: identity.name),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _identityField(
                        label: 'KELAS',
                        value: identity.className,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _identityField(
                        label: 'NO ABSEN',
                        value: identity.rollNumber,
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
                    onPressed: isSavingIdentity
                        ? null
                        : () => _showIdentityDialog(isRequired: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF148B4A),
                      side: const BorderSide(color: Color(0xFF95CAA9)),
                    ),
                    child: Text(
                        isSavingIdentity ? 'Menyimpan...' : 'Isi / Ubah Data'),
                  ),
                  Text(
                    identity.isReadyForExam
                        ? 'Data sudah lengkap. Kamu siap mulai ujian.'
                        : hasAssignedClass
                            ? 'Lengkapi dulu nama dan no absen.'
                            : 'Kelas belum ditetapkan admin. Hubungi guru/admin.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: identity.isReadyForExam
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

  Widget _buildExamCards({
    required bool isIdentityReady,
    required bool hasAssignedClass,
    required bool isStandbyActive,
    required bool isCompact,
    required List<ApiSubject> subjects,
    required List<ResultResponse> results,
    required Map<String, _SubjectQuestionStat> stats,
  }) {
    final cards = subjects.map((subject) {
      final stat = stats[subject.id] ??
          const _SubjectQuestionStat(questionCount: 0, totalWeight: 0);
      final attempts = _attemptCount(
        results: results,
        subject: subject,
      );
      final canStart = _canStartSubject(
        isIdentityReady: isIdentityReady,
        isStandbyActive: isStandbyActive,
        attemptsUsed: attempts,
        attemptLimit: subject.attemptLimit,
        stat: stat,
      );
      final statusText = _subjectStatusText(
        isIdentityReady: isIdentityReady,
        hasAssignedClass: hasAssignedClass,
        isStandbyActive: isStandbyActive,
        subject: subject,
        stat: stat,
        attemptsUsed: attempts,
      );
      final isStarting = _startingSubjectId == subject.id;

      return _buildExamCard(
        subject: subject,
        stat: stat,
        attemptsUsed: attempts,
        canStart: canStart,
        statusText: statusText,
        isStarting: isStarting,
      );
    }).toList();

    if (isCompact) {
      return Column(
        children: cards
            .map(
              (card) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: card,
              ),
            )
            .toList(),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: cards
          .map(
            (card) => SizedBox(
              width: 460,
              child: card,
            ),
          )
          .toList(),
    );
  }

  Widget _buildExamCard({
    required ApiSubject subject,
    required _SubjectQuestionStat stat,
    required int attemptsUsed,
    required bool canStart,
    required String statusText,
    required bool isStarting,
  }) {
    final cardColor =
        canStart ? const Color(0xFFEFF9F0) : const Color(0xFFFFF4F1);
    final borderColor =
        canStart ? const Color(0xFFA7D5B4) : const Color(0xFFE2B8AE);
    final tagColor =
        canStart ? const Color(0xFF1F8A4C) : const Color(0xFF9C3D2E);
    final buttonColor =
        canStart ? const Color(0xFF168B4B) : const Color(0xFF9CA3AF);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        color: cardColor,
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  subject.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2F2B1F),
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusTag(
                label: canStart ? 'Siap Dimulai' : 'Belum Siap',
                background: tagColor,
              ),
            ],
          ),
          if (subject.description.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subject.description.trim(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5D5744),
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              _InfoPill(label: '${subject.durationMinutes} menit'),
              _InfoPill(label: 'Batas ${subject.attemptLimit}x'),
              _InfoPill(
                  label: 'Percobaan $attemptsUsed/${subject.attemptLimit}'),
              _InfoPill(label: 'Soal ${stat.questionCount}'),
              _InfoPill(label: 'Bobot ${_formatWeight(stat.totalWeight)}/100'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              border: Border.all(
                color: canStart
                    ? const Color(0xFFB8DCC3)
                    : const Color(0xFFE9CCC6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Jadwal Ujian',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4A4637),
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subjectScheduleText(subject),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6E6754),
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  statusText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: canStart
                            ? const Color(0xFF19693A)
                            : const Color(0xFF8A3F28),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: !canStart || _startingSubjectId != null
                  ? null
                  : () => _confirmStartExam(
                        subject: subject,
                        stat: stat,
                        attemptsUsed: attemptsUsed,
                      ),
              style: FilledButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: isStarting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(isStarting ? 'Memulai...' : 'Mulai Ujian'),
            ),
          ),
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
    await ref.read(authProvider.notifier).refreshProfile();
    ref.invalidate(myClassOptionsProvider);
    ref.invalidate(studentScopedSubjectListProvider);
    ref.invalidate(myResultsProvider);
    ref.invalidate(subjectQuestionStatsProvider);
    ref.invalidate(proctoringStandbyStatusProvider);

    try {
      await ref.read(studentScopedSubjectListProvider.future);
    } catch (_) {}
    try {
      await ref.read(myResultsProvider.future);
    } catch (_) {}
  }

  int _attemptCount({
    required List<ResultResponse> results,
    required ApiSubject subject,
  }) {
    final targetSubject = subject.name.trim().toLowerCase();

    var count = 0;
    for (final item in results) {
      final subjectName = (item.subjectName ?? '').trim().toLowerCase();
      if (subjectName != targetSubject) {
        continue;
      }
      count += 1;
    }
    return count;
  }

  bool _canStartSubject({
    required bool isIdentityReady,
    required bool isStandbyActive,
    required int attemptsUsed,
    required int attemptLimit,
    required _SubjectQuestionStat stat,
  }) {
    if (!isIdentityReady) {
      return false;
    }
    if (attemptsUsed >= attemptLimit) {
      return false;
    }
    if (stat.questionCount <= 0) {
      return false;
    }
    if ((stat.totalWeight - 100).abs() >= 0.001) {
      return false;
    }
    return isStandbyActive;
  }

  String _subjectStatusText({
    required bool isIdentityReady,
    required bool hasAssignedClass,
    required bool isStandbyActive,
    required ApiSubject subject,
    required _SubjectQuestionStat stat,
    required int attemptsUsed,
  }) {
    if (!hasAssignedClass) {
      return 'Kelas belum ditetapkan admin. Hubungi guru/admin.';
    }
    if (!isIdentityReady) {
      return 'Lengkapi data anak dulu sebelum mulai ujian.';
    }
    if (attemptsUsed >= subject.attemptLimit) {
      return 'Batas percobaan untuk ${subject.name} sudah habis (${subject.attemptLimit}x).';
    }
    if (stat.questionCount <= 0) {
      return 'Ujian ${subject.name} belum memiliki soal.';
    }
    if ((stat.totalWeight - 100).abs() >= 0.001) {
      return 'Bobot soal ${subject.name} baru ${_formatWeight(stat.totalWeight)}/100. Hubungi guru/admin.';
    }
    if (!isStandbyActive) {
      return 'Pengawas/admin belum konfirmasi standby. Tunggu pengawas aktif dulu.';
    }
    return 'Ujian ${subject.name} siap. Tekan tombol Mulai pada card ini untuk memulai percobaan berikutnya.';
  }

  String _formatWeight(num value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.001) {
      return '${rounded.toInt()}';
    }
    return value.toStringAsFixed(1);
  }

  void _scheduleIdentityPromptIfNeeded({
    required AuthUser? user,
    required _StudentIdentity identity,
    required bool isSavingIdentity,
  }) {
    if (user == null || user.role != UserRole.siswa) {
      return;
    }
    if (identity.hasEditableFieldsComplete ||
        isSavingIdentity ||
        _isIdentityDialogOpen ||
        _identityPromptScheduled) {
      return;
    }

    _identityPromptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _identityPromptScheduled = false;
      if (!mounted) {
        return;
      }
      await _showIdentityDialog(isRequired: true);
    });
  }

  _StudentIdentity _identityFromUser(AuthUser? user) {
    return _StudentIdentity(
      name: _normalizedIdentityField(user?.fullName),
      classId: _normalizedIdentityField(user?.classId),
      className: _normalizedIdentityField(user?.className),
      rollNumber: _normalizedIdentityField(user?.rollNumber),
    );
  }

  String _normalizedIdentityField(String? value) {
    return value?.trim() ?? '';
  }

  String _subjectScheduleText(ApiSubject subject) {
    final publishAt = subject.publishAt;
    final closeAt = subject.closeAt;
    if (publishAt == null && closeAt == null) {
      return 'Terbuka sepanjang waktu.';
    }
    if (publishAt != null && closeAt != null) {
      return '${_formatDateTime(publishAt)} - ${_formatDateTime(closeAt)}';
    }
    if (publishAt != null) {
      return 'Mulai ${_formatDateTime(publishAt)}';
    }
    return 'Tutup ${_formatDateTime(closeAt!)}';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }

  Future<void> _confirmStartExam({
    required ApiSubject subject,
    required _SubjectQuestionStat stat,
    required int attemptsUsed,
  }) async {
    if (_startingSubjectId != null) {
      return;
    }

    final attemptNumber = attemptsUsed + 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Konfirmasi Mulai Ujian'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Ujian: ${subject.name}'),
              const SizedBox(height: AppSpacing.xs),
              Text('Durasi: ${subject.durationMinutes} menit'),
              Text('Percobaan: $attemptNumber dari ${subject.attemptLimit}'),
              Text('Jumlah soal: ${stat.questionCount}'),
              Text('Bobot: ${_formatWeight(stat.totalWeight)}/100'),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Setelah dimulai, timer ujian langsung berjalan.',
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Ya, Mulai'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    await _startExam(subject: subject);
  }

  Future<void> _startExam({
    required ApiSubject subject,
  }) async {
    if (_startingSubjectId != null) {
      return;
    }

    final currentIdentity = _identityFromUser(ref.read(authProvider).user);
    if (!currentIdentity.hasEditableFieldsComplete) {
      await _showIdentityDialog(isRequired: true);
      if (!mounted) {
        return;
      }
      final refreshedIdentity = _identityFromUser(ref.read(authProvider).user);
      if (!refreshedIdentity.hasEditableFieldsComplete) {
        return;
      }
    }

    String? selectedClassId = ref.read(effectiveStudentClassIdProvider);
    if (selectedClassId == null || selectedClassId.trim().isEmpty) {
      try {
        final classes = await ref.read(myClassOptionsProvider.future);
        if (classes.isNotEmpty) {
          selectedClassId = classes.first.id;
          await ref
              .read(studentSelectedClassIdProvider.notifier)
              .setSelectedClassId(selectedClassId);
        }
      } catch (_) {}
    }

    if (selectedClassId == null || selectedClassId.trim().isEmpty) {
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kelas belum ditetapkan admin. Hubungi guru/admin.'),
        ),
      );
      return;
    }

    try {
      final standbyStatus =
          await ref.read(proctoringStandbyStatusProvider.future);
      if (!standbyStatus.isActive) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pengawas/admin belum konfirmasi standby. Tunggu pengawas aktif dulu.',
            ),
          ),
        );
        return;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Status standby pengawas belum bisa dicek. Coba lagi beberapa saat.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _startingSubjectId = subject.id;
    });

    try {
      await ref.read(examSessionProvider.notifier).startAttempt(
            subject: subject,
            classId: selectedClassId,
          );
    } finally {
      if (mounted) {
        setState(() {
          _startingSubjectId = null;
        });
      }
    }

    if (!mounted) {
      return;
    }

    final session = ref.read(examSessionProvider);
    if (session.hasActiveAttempt) {
      context.go('/exam/session/precheck');
      return;
    }

    final message = session.errorMessage ?? 'Ujian belum bisa dimulai.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showIdentityDialog({required bool isRequired}) async {
    if (_isIdentityDialogOpen) {
      return;
    }

    _isIdentityDialogOpen = true;
    try {
      while (mounted) {
        final user = ref.read(authProvider).user;
        if (user == null) {
          return;
        }
        final initial = _identityFromUser(user);
        final updated = await showDialog<_StudentIdentity>(
          context: context,
          barrierDismissible: !isRequired,
          builder: (context) => _StudentIdentityDialog(
            initial: initial,
            requiredFill: isRequired,
          ),
        );
        if (updated == null) {
          return;
        }

        final error =
            await ref.read(authProvider.notifier).updateStudentIdentity(
                  fullName: updated.name,
                  rollNumber: updated.rollNumber,
                );
        if (!mounted) {
          return;
        }

        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isRequired
                    ? 'Data siswa berhasil disimpan.'
                    : 'Data siswa berhasil diperbarui.',
              ),
            ),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        if (!isRequired) {
          return;
        }
      }
    } finally {
      _isIdentityDialogOpen = false;
    }
  }
}

class _StudentIdentityDialog extends StatefulWidget {
  const _StudentIdentityDialog({
    required this.initial,
    required this.requiredFill,
  });

  final _StudentIdentity initial;
  final bool requiredFill;

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
    return PopScope(
      canPop: !widget.requiredFill,
      child: AlertDialog(
        title: Text(
          widget.requiredFill ? 'Lengkapi Data Siswa' : 'Ubah Data Siswa',
        ),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Nama'),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) {
                      return 'Nama wajib diisi';
                    }
                    if (text.length > 120) {
                      return 'Nama maksimal 120 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _classController,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Kelas'),
                  enabled: false,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _rollController,
                  textInputAction: TextInputAction.done,
                  maxLength: 30,
                  decoration: const InputDecoration(labelText: 'No Absen'),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) {
                      return 'No absen wajib diisi';
                    }
                    if (text.length > 30) {
                      return 'No absen maksimal 30 karakter';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (!(_formKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    Navigator.of(context).pop(
                      widget.initial.copyWith(
                        name: _nameController.text.trim(),
                        rollNumber: _rollController.text.trim(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          if (!widget.requiredFill)
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
                  rollNumber: _rollController.text.trim(),
                ),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({
    required this.label,
    required this.background,
  });

  final String label;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFF16A34A),
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
