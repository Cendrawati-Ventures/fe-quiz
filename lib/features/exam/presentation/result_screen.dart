import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_button.dart';
import '../../../shared/components/app_card.dart';
import '../model/exam_models.dart';
import '../state/exam_state.dart';
import 'widgets/student_layout.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(examSessionProvider);
    final resultsAsync = ref.watch(myResultsProvider);

    final latest = sessionState.latestResult;

    return StudentLayout(
      title: 'Hasil Ujian',
      subtitle: 'Riwayat nilai dari ujian yang sudah kamu kumpulkan.',
      activeSection: StudentSection.results,
      child: ListView(
        children: <Widget>[
          if (latest != null) ...<Widget>[
            _ResultCard(title: 'Hasil Terbaru', result: latest),
            const SizedBox(height: AppSpacing.md),
          ],
          resultsAsync.when(
            data: (results) {
              if (results.isEmpty) {
                return const AppCard(
                  title: 'Hasil masih kosong',
                  subtitle: 'Kamu belum mengerjakan ujian.',
                );
              }
              return Column(
                children: results
                    .map(
                      (result) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _ResultCard(
                          title: result.examTitle ?? 'Hasil',
                          result: result,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AppCard(
              title: 'Gagal memuat hasil',
              subtitle: error.toString(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Kembali ke Daftar Ujian',
            onPressed: () => context.go('/exam'),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.result,
  });

  final String title;
  final ResultResponse result;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: title,
      subtitle:
          'Nilai: ${result.score}\nBenar: ${result.correct}\nSalah: ${result.wrong}\nRisiko: ${riskLevelLabel(result.riskLevel)}',
      status: result.subjectName,
    );
  }
}
