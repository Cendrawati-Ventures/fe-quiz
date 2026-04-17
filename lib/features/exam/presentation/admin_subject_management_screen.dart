import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_button.dart';
import '../../../shared/components/app_card.dart';
import '../../../shared/components/app_snackbar.dart';
import '../model/exam_models.dart';
import '../state/admin_subject_state.dart';
import '../state/exam_state.dart';
import 'widgets/subject_form_fields.dart';

class AdminSubjectManagementScreen extends ConsumerStatefulWidget {
  const AdminSubjectManagementScreen({super.key});

  @override
  ConsumerState<AdminSubjectManagementScreen> createState() =>
      _AdminSubjectManagementScreenState();
}

class _AdminSubjectManagementScreenState
    extends ConsumerState<AdminSubjectManagementScreen> {
  Future<void> _showQuickCreateDialog() async {
    final created = await showDialog<ApiSubject>(
      context: context,
      builder: (_) => const _QuickCreateSubjectDialog(),
    );

    if (!mounted || created == null) {
      return;
    }

    AppSnackBar.success(
      context,
      'Subject berhasil dibuat. Lanjutkan edit lengkap.',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.push('/admin/subjects/${created.id}/edit');
    });
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Subject Management')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppButton(
              label: 'Quick Create Subject',
              onPressed: _showQuickCreateDialog,
            ),
            const SizedBox(height: AppSpacing.md),
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
                            '${item.description}\nDuration: ${item.durationMinutes} menit\nAttempt limit: ${item.attemptLimit}',
                        status: item.allowReview ? 'Allow Review' : 'No Review',
                        child: AppButton(
                          label: 'Edit Subject',
                          variant: AppButtonVariant.secondary,
                          onPressed: () =>
                              context.push('/admin/subjects/${item.id}/edit'),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const AppCard(
                  title: 'Gagal memuat subject',
                  subtitle: 'Data subject belum bisa dimuat. Coba lagi sebentar.',
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

class _QuickCreateSubjectDialog extends ConsumerStatefulWidget {
  const _QuickCreateSubjectDialog();

  @override
  ConsumerState<_QuickCreateSubjectDialog> createState() =>
      _QuickCreateSubjectDialogState();
}

class _QuickCreateSubjectDialogState
    extends ConsumerState<_QuickCreateSubjectDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController =
      TextEditingController(text: '90');

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final created = await ref.read(adminSubjectActionProvider.notifier).quickCreate(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          durationMinutes: int.parse(_durationController.text.trim()),
        );

    if (!mounted) {
      return;
    }

    if (created != null) {
      Navigator.of(context).pop(created);
      return;
    }

    final error = ref.read(adminSubjectActionProvider).errorMessage;
    AppSnackBar.error(context, error ?? 'Gagal membuat subject');
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(adminSubjectActionProvider);

    return AlertDialog(
      title: const Text('Quick Create Subject'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Isi data minimum dulu (nama, deskripsi, durasi). Setelah dibuat, kamu akan langsung diarahkan ke halaman edit lengkap.',
              ),
              const SizedBox(height: AppSpacing.md),
              SubjectFormFields(
                nameController: _nameController,
                descriptionController: _descriptionController,
                durationMinutesController: _durationController,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed:
              actionState.isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: actionState.isCreating ? null : _submit,
          child: actionState.isCreating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Buat & Lanjut Edit'),
        ),
      ],
    );
  }
}
