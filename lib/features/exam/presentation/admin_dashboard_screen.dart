import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/spacing.dart';
import '../../auth/state/auth_provider.dart';
import '../model/exam_models.dart';
import '../service/student_account_service.dart';
import '../state/exam_state.dart';
import 'widgets/admin_layout.dart';

final adminDashboardQuestionTotalProvider = FutureProvider<int>((ref) async {
  final subjects = await ref.watch(subjectListProvider.future);
  if (subjects.isEmpty) {
    return 0;
  }

  final service = ref.watch(examServiceProvider);
  final questionLists = await Future.wait(
    subjects.map((subject) => service.listQuestionsBySubject(subject.id)),
  );
  return questionLists.fold<int>(
    0,
    (total, questions) => total + questions.length,
  );
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(
            authProvider.select((state) => state.user?.effectiveDisplayName)) ??
        'Admin';
    final subjectsAsync = ref.watch(subjectListProvider);
    final resultsAsync = ref.watch(adminResultsProvider);
    final studentsAsync = ref.watch(studentAccountsProvider);
    final questionsAsync = ref.watch(adminDashboardQuestionTotalProvider);

    final totalSubjects =
        subjectsAsync.maybeWhen(data: (items) => items.length, orElse: () => 0);
    final totalResults =
        resultsAsync.maybeWhen(data: (items) => items.length, orElse: () => 0);
    final totalStudents =
        studentsAsync.maybeWhen(data: (items) => items.length, orElse: () => 0);
    final totalQuestions =
        questionsAsync.maybeWhen(data: (items) => items, orElse: () => 0);

    final highRiskCount = resultsAsync.maybeWhen(
      data: (items) =>
          items.where((item) => item.riskLevel == RiskLevel.highRisk).length,
      orElse: () => 0,
    );
    final cautionCount = resultsAsync.maybeWhen(
      data: (items) =>
          items.where((item) => item.riskLevel == RiskLevel.suspicious).length,
      orElse: () => 0,
    );

    return AdminLayout(
      title: 'Beranda Admin',
      subtitle: 'Ringkasan data untuk pengelolaan ujian harian.',
      activeSection: AdminSection.dashboard,
      child: ListView(
        children: <Widget>[
          _HeroCard(userName: userName),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1200
                  ? 4
                  : (constraints.maxWidth >= 700 ? 2 : 1);
              final width =
                  (constraints.maxWidth - ((columns - 1) * AppSpacing.sm)) /
                      columns;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      icon: Icons.menu_book_rounded,
                      title: 'Mata Pelajaran',
                      value: '$totalSubjects',
                      caption: 'Total materi yang siap dipakai ujian',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      icon: Icons.quiz_rounded,
                      title: 'Jumlah Soal',
                      value: '$totalQuestions',
                      caption: 'Total soal aktif dari semua mapel',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      icon: Icons.group_rounded,
                      title: 'Akun Siswa',
                      value: '$totalStudents',
                      caption: 'Peserta yang sudah bisa login',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      icon: Icons.analytics_rounded,
                      title: 'Hasil Masuk',
                      value: '$totalResults',
                      caption: 'Data nilai yang sudah terkirim',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Ringkasan Pengawasan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Pantau tingkat risiko agar guru dapat menindaklanjuti lebih cepat.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _RiskPill(
                        title: 'Risiko Tinggi',
                        value: '$highRiskCount',
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _RiskPill(
                        title: 'Perlu Perhatian',
                        value: '$cautionCount',
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _LatestResultsPanel(resultsAsync: resultsAsync),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            theme.colorScheme.primary.withValues(alpha: 0.95),
            const Color(0xFF246A3F),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Selamat bekerja, $userName',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Panel ini dirancang untuk membantu admin dan guru mengelola ujian dengan cepat, rapi, dan terarah.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              'Mode Admin',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final String title;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskPill extends StatelessWidget {
  const _RiskPill({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.flag_rounded, color: color, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _LatestResultsPanel extends StatelessWidget {
  const _LatestResultsPanel({required this.resultsAsync});

  final AsyncValue<List<ResultResponse>> resultsAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Ringkasan Hasil Terbaru',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Lima data terakhir untuk pemantauan cepat.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          resultsAsync.when(
            data: (results) {
              if (results.isEmpty) {
                return const Text(
                  'Belum ada hasil ujian yang masuk.',
                );
              }
              final latest = results.take(5).toList();
              return Column(
                children: latest.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text(
                          '${item.score}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      title: Text(item.username ?? 'Siswa'),
                      subtitle: Text(
                        '${item.examTitle ?? 'Ujian'} - ${item.subjectName ?? '-'}',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: _riskColor(item.riskLevel)
                              .withValues(alpha: 0.14),
                        ),
                        child: Text(
                          riskLevelLabel(item.riskLevel),
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: _riskColor(item.riskLevel),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const Text(
              'Data hasil belum bisa dimuat saat ini.',
            ),
          ),
        ],
      ),
    );
  }

  Color _riskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return const Color(0xFF1F8A4C);
      case RiskLevel.suspicious:
        return const Color(0xFFD08900);
      case RiskLevel.highRisk:
        return const Color(0xFFD12D2D);
    }
  }
}
