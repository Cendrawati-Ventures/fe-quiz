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
import 'widgets/admin_layout.dart';
import 'widgets/subject_form_fields.dart';

class AdminSubjectManagementScreen extends ConsumerStatefulWidget {
  const AdminSubjectManagementScreen({super.key});

  @override
  ConsumerState<AdminSubjectManagementScreen> createState() =>
      _AdminSubjectManagementScreenState();
}

class _AdminSubjectManagementScreenState
    extends ConsumerState<AdminSubjectManagementScreen> {
  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  String _scheduleStatus(ApiSubject item) {
    final now = DateTime.now().toUtc();
    final publishAt = item.publishAt?.toUtc();
    final closeAt = item.closeAt?.toUtc();

    if (publishAt == null || closeAt == null) {
      return 'Jadwal publish/close belum diatur';
    }
    if (now.isBefore(publishAt)) {
      return 'Terjadwal (belum publish)';
    }
    if (now.isAfter(closeAt)) {
      return 'Closed';
    }
    return 'Aktif';
  }

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
      'Ujian berhasil dibuat. Lanjutkan dengan pengaturan lengkap.',
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
    return AdminLayout(
      title: 'Kelola Ujian',
      subtitle: 'Atur data ujian, jadwal publish-close, dan batas percobaan.',
      activeSection: AdminSection.subjects,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppButton(
            label: 'Buat Ujian Cepat',
            onPressed: _showQuickCreateDialog,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: subjectsAsync.when(
              data: (subjects) {
                if (subjects.isEmpty) {
                  return const AppCard(
                    title: 'Ujian masih kosong',
                    subtitle: 'Belum ada ujian.',
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
                          '${item.description}\nPublish: ${_formatDateTime(item.publishAt)}\nClose: ${_formatDateTime(item.closeAt)}\nDurasi: ${item.durationMinutes} menit\nBatas percobaan: ${item.attemptLimit}',
                      status: item.allowReview
                          ? 'Siswa boleh meninjau jawaban - ${_scheduleStatus(item)}'
                          : 'Siswa tidak boleh meninjau jawaban - ${_scheduleStatus(item)}',
                      child: AppButton(
                        label: 'Ubah Ujian',
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
                title: 'Gagal memuat ujian',
                subtitle: 'Data ujian belum bisa dimuat. Coba lagi sebentar.',
              ),
            ),
          ),
        ],
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
  DateTime? _publishAt = DateTime.now();
  DateTime? _closeAt = DateTime.now().add(const Duration(hours: 2));

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

    final created =
        await ref.read(adminSubjectActionProvider.notifier).quickCreate(
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              durationMinutes: int.parse(_durationController.text.trim()),
              publishAt: _publishAt!,
              closeAt: _closeAt!,
            );

    if (!mounted) {
      return;
    }

    if (created != null) {
      Navigator.of(context).pop(created);
      return;
    }

    final error = ref.read(adminSubjectActionProvider).errorMessage;
    AppSnackBar.error(context, error ?? 'Gagal membuat ujian.');
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(adminSubjectActionProvider);
    final publishAt = _publishAt;
    final closeAt = _closeAt;
    final scheduleInvalid = publishAt == null ||
        closeAt == null ||
        !closeAt.isAfter(publishAt);

    return AlertDialog(
      title: const Text('Buat Ujian Cepat'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Isi data dasar dulu (nama, deskripsi, publish-close, durasi). Setelah dibuat, kamu bisa lanjut ke pengaturan lengkap.',
              ),
              const SizedBox(height: AppSpacing.md),
              SubjectFormFields(
                nameController: _nameController,
                descriptionController: _descriptionController,
                durationMinutesController: _durationController,
                publishAt: publishAt,
                closeAt: closeAt,
                onPublishAtChanged: (value) {
                  setState(() {
                    _publishAt = value;
                    if (_closeAt != null && !_closeAt!.isAfter(value)) {
                      _closeAt = value.add(const Duration(hours: 1));
                    }
                  });
                },
                onCloseAtChanged: (value) {
                  setState(() {
                    _closeAt = value;
                  });
                },
              ),
              if (scheduleInvalid) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Waktu close harus setelah publish.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
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
          onPressed: actionState.isCreating || scheduleInvalid ? null : _submit,
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
