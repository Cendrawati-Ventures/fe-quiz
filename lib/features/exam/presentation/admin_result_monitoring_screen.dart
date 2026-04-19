import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_card.dart';
import '../model/exam_models.dart';
import '../state/exam_state.dart';
import 'widgets/admin_layout.dart';

class AdminResultMonitoringScreen extends ConsumerWidget {
  const AdminResultMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(adminResultsProvider);
    return AdminLayout(
      title: 'Pantau Hasil Ujian',
      subtitle: 'Pantau nilai dan tingkat risiko peserta ujian.',
      activeSection: AdminSection.results,
      child: resultsAsync.when(
        data: (results) {
          if (results.isEmpty) {
            return const AppCard(
              title: 'Belum ada hasil',
              subtitle: 'Belum ada hasil ujian yang masuk.',
            );
          }
          return ListView.separated(
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final result = results[index];
              return AppCard(
                title: result.examTitle ?? 'Ujian',
                subtitle:
                    'Peserta: ${result.username ?? '-'}\nNilai: ${result.score}\nRisiko: ${riskLevelLabel(result.riskLevel)}',
                status: result.subjectName,
              );
            },
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
