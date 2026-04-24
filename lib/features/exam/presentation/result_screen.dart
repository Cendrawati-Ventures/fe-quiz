import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_card.dart';
import '../../auth/model/auth_user.dart';
import '../../auth/state/auth_provider.dart';
import '../model/exam_models.dart';
import '../state/exam_state.dart';
import 'widgets/student_layout.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(examSessionProvider);
    final user = ref.watch(authProvider.select((value) => value.user));
    final resultsAsync = ref.watch(myResultsProvider);

    return StudentLayout(
      title: 'Hasil Ujian',
      subtitle:
          'Rekap nilai ditulis otomatis agar dapat dibaca admin kapan saja.',
      activeSection: StudentSection.results,
      contentPadding: EdgeInsets.zero,
      child: RefreshIndicator(
        onRefresh: () => _refreshResults(ref),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _IdentityCard(user: user),
                    const SizedBox(height: AppSpacing.md),
                    resultsAsync.when(
                      data: (results) {
                        final latest = _resolveLatestResult(
                          sessionState: sessionState,
                          results: results,
                        );
                        if (latest == null) {
                          return const AppCard(
                            title: 'Hasil masih kosong',
                            subtitle: 'Kamu belum mengerjakan ujian.',
                          );
                        }

                        final otherResults = results
                            .where((item) =>
                                item.attemptId != latest.result.attemptId)
                            .toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _LatestResultCard(latest: latest),
                            if (otherResults.isNotEmpty) ...<Widget>[
                              const SizedBox(height: AppSpacing.md),
                              AppCard(
                                title: 'Riwayat Hasil Lainnya',
                                subtitle:
                                    'Nilai sebelumnya tetap tersimpan dan bisa dilihat lagi kapan saja.',
                                child: Column(
                                  children: otherResults
                                      .map(
                                        (result) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: AppSpacing.sm,
                                          ),
                                          child: _HistoryResultTile(
                                              result: result),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                      loading: () {
                        final latest = _resolveLatestResult(
                          sessionState: sessionState,
                          results: const <ResultResponse>[],
                        );
                        if (latest == null) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        return _LatestResultCard(latest: latest);
                      },
                      error: (error, _) {
                        final latest = _resolveLatestResult(
                          sessionState: sessionState,
                          results: const <ResultResponse>[],
                        );
                        if (latest != null) {
                          return _LatestResultCard(latest: latest);
                        }
                        return AppCard(
                          title: 'Gagal memuat hasil',
                          subtitle: error.toString(),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: 280,
                      child: FilledButton(
                        onPressed: () => context.go('/exam'),
                        child: const Text('Kembali ke Halaman Awal'),
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

  Future<void> _refreshResults(WidgetRef ref) async {
    ref.invalidate(myResultsProvider);
    try {
      await ref.read(myResultsProvider.future);
    } catch (_) {}
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final fullName = (user?.fullName?.trim().isNotEmpty == true)
        ? user!.fullName!.trim()
        : (user?.username ?? '-');
    final className = (user?.className?.trim().isNotEmpty == true)
        ? user!.className!.trim()
        : '-';
    final rollNumber = (user?.rollNumber?.trim().isNotEmpty == true)
        ? user!.rollNumber!.trim()
        : '-';
    final hasIdentity = user?.hasCompleteStudentIdentity ?? false;

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
              _sectionTag(context, 'DATA ANAK'),
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
                'Pastikan ketiga data di bawah sudah benar sebelum mulai mengerjakan soal ya.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6C624F),
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (compact) ...<Widget>[
                _identityField(context, label: 'NAMA', value: fullName),
                const SizedBox(height: AppSpacing.sm),
                _identityField(context, label: 'KELAS', value: className),
                const SizedBox(height: AppSpacing.sm),
                _identityField(context, label: 'NO ABSEN', value: rollNumber),
              ] else
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _identityField(context,
                          label: 'NAMA', value: fullName),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _identityField(context,
                          label: 'KELAS', value: className),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _identityField(
                        context,
                        label: 'NO ABSEN',
                        value: rollNumber,
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
                    onPressed: () => context.go('/exam'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF148B4A),
                      side: const BorderSide(color: Color(0xFF95CAA9)),
                    ),
                    child: const Text('Isi / Ubah Data'),
                  ),
                  Text(
                    hasIdentity
                        ? 'Data sudah lengkap. Kamu siap mulai petualangan!'
                        : 'Lengkapi data siswa dulu sebelum mulai ujian.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: hasIdentity
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

  Widget _sectionTag(BuildContext context, String label) {
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

  Widget _identityField(
    BuildContext context, {
    required String label,
    required String value,
  }) {
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
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3F341F),
              ),
        ),
      ],
    );
  }
}

class _LatestResultCard extends StatelessWidget {
  const _LatestResultCard({required this.latest});

  final _LatestResultView latest;

  @override
  Widget build(BuildContext context) {
    final subjectName = (latest.result.subjectName?.trim().isNotEmpty == true)
        ? latest.result.subjectName!.trim()
        : (latest.subject?.name ?? '-');
    final durationMinutes = latest.subject?.durationMinutes;
    final attemptProgress = (latest.attempt != null && latest.subject != null)
        ? '${latest.attempt!.attemptNo}/${latest.subject!.attemptLimit}'
        : '-';
    final totalQuestion = latest.result.correct + latest.result.wrong;
    final allowReview = latest.subject?.allowReview ?? false;
    final proctoringSummaryText = _proctoringSummaryText(
      latest.result.proctoringReport,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFFF6F5EF),
        border: Border.all(color: const Color(0xFFC9D2BF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionTag(context, 'LANGKAH 3'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Hasil Ujian',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3F341F),
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Rekap nilai dituliskan otomatis agar dapat dibaca Admin kapan saja.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6C624F),
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Mata pelajaran: $subjectName | Durasi ${durationMinutes ?? '-'} menit | Pengulangan $attemptProgress',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6C624F),
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Durasi pengerjaan: ${_formatDuration(latest.result.duration)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6C624F),
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF3F341F),
                    height: 1.35,
                  ),
              children: <InlineSpan>[
                const TextSpan(text: 'Benar: '),
                TextSpan(
                  text: '${latest.result.correct}\n',
                  style: const TextStyle(
                    color: Color(0xFF0DA35C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: 'Salah: '),
                TextSpan(
                  text: '${latest.result.wrong}\n',
                  style: const TextStyle(
                    color: Color(0xFFC83C3C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: 'Total Soal: '),
                TextSpan(
                  text: '$totalQuestion',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Nilai: ${latest.result.score}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF3F341F),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Nilai kamu juga tersimpan di server offline dan dapat dilihat admin.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6C624F),
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildProctoringInfo(
            context,
            report: latest.result.proctoringReport,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            proctoringSummaryText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6C624F),
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              FilledButton(
                onPressed: () => context.go('/exam'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Kembali ke Halaman Awal'),
              ),
              OutlinedButton(
                onPressed: () => _showReviewInfo(
                  context: context,
                  allowReview: allowReview,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF148B4A),
                  side: const BorderSide(color: Color(0xFF95CAA9)),
                ),
                child: const Text('Lihat Jawaban Benar/Salah'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tekan tombol di atas untuk melihat detail jawaban benar dan salah.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6C624F),
                ),
          ),
          if (!allowReview) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Belum menemukan Admin untuk menerima nilai.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFD22E2E),
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTag(BuildContext context, String label) {
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

  Widget _buildProctoringInfo(
    BuildContext context, {
    required ProctoringReport? report,
  }) {
    final notes = _buildProctoringNotes(report);
    final hasNotes = notes.isNotEmpty;
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: const Color(0xFF3F341F),
          fontWeight: FontWeight.w700,
        );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF6C624F),
          height: 1.45,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF1EFE5),
        border: Border.all(color: const Color(0xFFD8D3BE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Laporan Pengawasan (Informasi)', style: titleStyle),
          const SizedBox(height: AppSpacing.xxs),
          if (!hasNotes)
            Text(
              'Tidak ada kejadian mencurigakan yang tercatat pada sesi ini.',
              style: bodyStyle,
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: notes
                  .map(
                    (note) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('- $note', style: bodyStyle),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _showReviewInfo({
    required BuildContext context,
    required bool allowReview,
  }) async {
    final message = allowReview
        ? 'Fitur detail jawaban benar/salah belum tersedia pada versi ini.'
        : 'Guru/Admin belum mengaktifkan fitur review jawaban untuk ujian ini.';

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lihat Jawaban'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

class _HistoryResultTile extends StatelessWidget {
  const _HistoryResultTile({required this.result});

  final ResultResponse result;

  @override
  Widget build(BuildContext context) {
    final total = result.correct + result.wrong;
    final summary = _proctoringSummaryText(result.proctoringReport);
    return AppCard(
      title: result.examTitle ?? 'Hasil Ujian',
      subtitle:
          '${result.subjectName ?? '-'}\nNilai: ${result.score} | Benar: ${result.correct} | Salah: ${result.wrong} | Total: $total\nPengawasan: $summary',
      status: 'Durasi: ${_formatDuration(result.duration)}',
    );
  }
}

class _LatestResultView {
  const _LatestResultView({
    required this.result,
    required this.subject,
    required this.attempt,
  });

  final ResultResponse result;
  final ApiSubject? subject;
  final ApiAttempt? attempt;
}

_LatestResultView? _resolveLatestResult({
  required ExamSessionState sessionState,
  required List<ResultResponse> results,
}) {
  final sessionLatest = sessionState.latestResult;

  if (sessionLatest != null) {
    var merged = sessionLatest;
    for (final item in results) {
      if (item.attemptId == sessionLatest.attemptId) {
        merged = ResultResponse(
          id: sessionLatest.id,
          attemptId: sessionLatest.attemptId,
          examId: sessionLatest.examId ?? item.examId,
          subjectId: sessionLatest.subjectId ?? item.subjectId,
          classId: sessionLatest.classId ?? item.classId,
          className: sessionLatest.className ?? item.className,
          score: sessionLatest.score,
          correct: sessionLatest.correct,
          wrong: sessionLatest.wrong,
          duration: sessionLatest.duration,
          cheatScore: sessionLatest.cheatScore,
          riskLevel: sessionLatest.riskLevel,
          examTitle: item.examTitle ?? sessionLatest.examTitle,
          subjectName: item.subjectName ?? sessionLatest.subjectName,
          username: item.username ?? sessionLatest.username,
          proctoringReport:
              item.proctoringReport ?? sessionLatest.proctoringReport,
        );
        break;
      }
    }

    final currentAttempt = sessionState.attempt;
    final isCurrentAttempt = currentAttempt?.id == merged.attemptId;

    return _LatestResultView(
      result: merged,
      subject: isCurrentAttempt ? sessionState.subject : null,
      attempt: isCurrentAttempt ? currentAttempt : null,
    );
  }

  if (results.isEmpty) {
    return null;
  }

  return _LatestResultView(
    result: results.first,
    subject: null,
    attempt: null,
  );
}

List<String> _buildProctoringNotes(ProctoringReport? report) {
  if (report == null) {
    return const <String>[];
  }

  final normalizedNotes = report.notes
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
  if (normalizedNotes.isNotEmpty) {
    return normalizedNotes;
  }

  final fallback = <String>[];
  if (report.tabSwitchCount > 0) {
    fallback.add(
      'Perpindahan tab/jendela: ${report.tabSwitchCount} kali.',
    );
  }
  if (report.appBackgroundCount > 0) {
    fallback.add(
      'Aplikasi keluar/latar belakang: ${report.appBackgroundCount} kali.',
    );
  }
  if (report.idleCount > 0) {
    final maxIdle = report.maxIdleSeconds;
    fallback.add(
      maxIdle == null
          ? 'Tidak aktif: ${report.idleCount} kali.'
          : 'Tidak aktif: ${report.idleCount} kali (maks $maxIdle detik).',
    );
  }
  if (report.noiseCount > 0) {
    final maxNoise = report.maxNoiseLevel;
    fallback.add(
      maxNoise == null
          ? 'Kebisingan/indikasi percakapan: ${report.noiseCount} kali.'
          : 'Kebisingan/indikasi percakapan: ${report.noiseCount} kali (maks $maxNoise/100).',
    );
  }

  return fallback;
}

String _proctoringSummaryText(ProctoringReport? report) {
  final notes = _buildProctoringNotes(report);
  if (notes.isEmpty) {
    return 'Tidak ada indikasi mencurigakan.';
  }

  return '${notes.length} indikator tercatat sebagai informasi.';
}

String _formatDuration(int seconds) {
  if (seconds <= 0) {
    return '0 detik';
  }

  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainingSeconds = seconds % 60;
  final parts = <String>[];

  if (hours > 0) {
    parts.add('$hours jam');
  }
  if (minutes > 0) {
    parts.add('$minutes menit');
  }
  if (remainingSeconds > 0) {
    parts.add('$remainingSeconds detik');
  }

  return parts.join(' ');
}
