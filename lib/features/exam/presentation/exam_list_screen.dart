import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_button.dart';
import '../../../shared/components/app_card.dart';
import '../../auth/state/auth_provider.dart';
import '../state/exam_state.dart';

class ExamListScreen extends ConsumerWidget {
  const ExamListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(examListProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Ujian'),
        actions: <Widget>[
          IconButton(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: examsAsync.when(
          data: (exams) {
            if (exams.isEmpty) {
              return const Center(
                child: Text('Belum ada ujian tersedia.'),
              );
            }

            return ListView.separated(
              itemCount: exams.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final exam = exams[index];
                final subtitle =
                    'Mulai: ${exam.startTime.toLocal()} \nSelesai: ${exam.endTime.toLocal()}';
                return AppCard(
                  title: exam.title,
                  subtitle: subtitle,
                  status: authState.user?.role.name ?? 'siswa',
                  child: AppButton(
                    label: 'Lihat & Mulai',
                    onPressed: () => context.go('/exam/${exam.id}/start'),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(error.toString()),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Muat Ulang',
                  onPressed: () => ref.refresh(examListProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
