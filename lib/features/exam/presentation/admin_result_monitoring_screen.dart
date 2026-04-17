import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_button.dart';
import '../../../shared/components/app_card.dart';
import '../state/exam_state.dart';

class AdminResultMonitoringScreen extends ConsumerWidget {
  const AdminResultMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(adminResultsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Result Monitoring')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: resultsAsync.when(
                data: (results) {
                  if (results.isEmpty) {
                    return const AppCard(
                      title: 'Belum ada result',
                      subtitle: 'Result admin masih kosong.',
                    );
                  }
                  return ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final result = results[index];
                      return AppCard(
                        title: result.examTitle ?? 'Exam',
                        subtitle:
                            'User: ${result.username ?? '-'}\nScore: ${result.score}\nRisk: ${result.riskLevel.name}',
                        status: result.subjectName,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const AppCard(
                  title: 'Gagal memuat result',
                  subtitle: 'Data hasil belum bisa dimuat. Coba lagi sebentar.',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Kembali ke Dashboard',
              onPressed: () => context.go('/admin/dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
