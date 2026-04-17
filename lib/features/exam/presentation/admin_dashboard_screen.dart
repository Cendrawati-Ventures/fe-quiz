import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_button.dart';
import '../../../shared/components/app_card.dart';
import '../../auth/state/auth_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleName =
        ref.watch(authProvider.select((state) => state.user?.role.name));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: <Widget>[
          IconButton(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ListView(
          children: <Widget>[
            AppCard(
              title: 'Selamat Datang, Admin',
              subtitle:
                  'Kelola data ujian, bank soal, dan pantau hasil siswa dalam satu dashboard.',
              status: roleName ?? 'admin',
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              title: 'Subject Management',
              subtitle: 'Tambah atau cek durasi dan limit attempt per subject.',
              child: AppButton(
                label: 'Buka Subject Management',
                onPressed: () => context.go('/admin/subjects'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              title: 'Question Management',
              subtitle: 'Atur soal pilihan ganda, bobot, dan jawaban benar.',
              child: AppButton(
                label: 'Buka Question Management',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go('/admin/questions'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              title: 'Result Monitoring',
              subtitle: 'Pantau score dan risk level seluruh peserta.',
              child: AppButton(
                label: 'Buka Result Monitoring',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go('/admin/results'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
