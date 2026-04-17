import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_button.dart';
import '../../../shared/components/app_card.dart';
import '../state/exam_state.dart';

class AdminSubjectManagementScreen extends ConsumerWidget {
  const AdminSubjectManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Subject Management')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: subjectsAsync.when(
                data: (subjects) {
                  if (subjects.isEmpty) {
                    return const AppCard(
                      title: 'Subject kosong',
                      subtitle: 'Belum ada subject.',
                    );
                  }
                  return ListView.separated(
                    itemCount: subjects.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final item = subjects[index];
                      return AppCard(
                        title: item.name,
                        subtitle:
                            'Duration: ${item.durationMinutes} menit\nAttempt limit: ${item.attemptLimit}',
                        status: item.allowReview ? 'Allow Review' : 'No Review',
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => AppCard(
                  title: 'Gagal memuat subject',
                  subtitle: error.toString(),
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
