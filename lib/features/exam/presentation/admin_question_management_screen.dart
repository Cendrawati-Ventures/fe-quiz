import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_button.dart';
import '../../../shared/components/app_card.dart';

class AdminQuestionManagementScreen extends StatelessWidget {
  const AdminQuestionManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Question Management')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const AppCard(
              title: 'Question management',
              subtitle:
                  'Versi mobile basic tersedia sebagai placeholder routing. Integrasi CRUD dapat ditambahkan di iterasi berikutnya.',
            ),
            const SizedBox(height: AppSpacing.md),
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
