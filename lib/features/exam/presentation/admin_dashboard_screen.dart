import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_button.dart';
import '../../auth/state/auth_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppButton(
              label: 'Subject Management',
              onPressed: () => context.go('/admin/subjects'),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Question Management',
              onPressed: () => context.go('/admin/questions'),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Result Monitoring',
              onPressed: () => context.go('/admin/results'),
            ),
          ],
        ),
      ),
    );
  }
}
