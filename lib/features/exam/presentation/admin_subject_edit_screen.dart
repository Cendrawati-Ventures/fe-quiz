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

class AdminSubjectEditScreen extends ConsumerStatefulWidget {
  const AdminSubjectEditScreen({
    required this.subjectId,
    super.key,
  });

  final String subjectId;

  @override
  ConsumerState<AdminSubjectEditScreen> createState() =>
      _AdminSubjectEditScreenState();
}

class _AdminSubjectEditScreenState extends ConsumerState<AdminSubjectEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _attemptLimitController = TextEditingController();
  bool _allowReview = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _attemptLimitController.dispose();
    super.dispose();
  }

  void _initForm(ApiSubject subject) {
    if (_initialized) {
      return;
    }
    _nameController.text = subject.name;
    _descriptionController.text = subject.description;
    _durationController.text = subject.durationMinutes.toString();
    _attemptLimitController.text = subject.attemptLimit.toString();
    _allowReview = subject.allowReview;
    _initialized = true;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final durationMinutes = int.parse(_durationController.text.trim());
    final attemptLimit = int.parse(_attemptLimitController.text.trim());

    final updated = await ref.read(adminSubjectActionProvider.notifier).update(
          id: widget.subjectId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          durationMinutes: durationMinutes,
          attemptLimit: attemptLimit,
          allowReview: _allowReview,
        );

    if (!mounted) {
      return;
    }

    if (updated != null) {
      AppSnackBar.success(context, 'Subject berhasil diperbarui');
      context.go('/admin/subjects');
      return;
    }

    final error = ref.read(adminSubjectActionProvider).errorMessage;
    AppSnackBar.error(context, error ?? 'Gagal memperbarui subject');
  }

  Future<void> _deleteSubject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Subject'),
          content: const Text(
            'Yakin ingin menghapus subject ini? Tindakan ini tidak bisa dibatalkan.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final deleted =
        await ref.read(adminSubjectActionProvider.notifier).delete(widget.subjectId);

    if (!mounted) {
      return;
    }

    if (deleted) {
      AppSnackBar.success(context, 'Subject berhasil dihapus');
      context.go('/admin/subjects');
      return;
    }

    final error = ref.read(adminSubjectActionProvider).errorMessage;
    AppSnackBar.error(context, error ?? 'Gagal menghapus subject');
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectListProvider);
    final actionState = ref.watch(adminSubjectActionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Subject')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: subjectsAsync.when(
          data: (subjects) {
            ApiSubject? subject;
            for (final item in subjects) {
              if (item.id == widget.subjectId) {
                subject = item;
                break;
              }
            }

            if (subject == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const AppCard(
                    title: 'Subject tidak ditemukan',
                    subtitle:
                        'Data subject belum tersedia. Silakan kembali dan refresh daftar.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Kembali ke Subject Management',
                    onPressed: () => context.go('/admin/subjects'),
                  ),
                ],
              );
            }

            _initForm(subject);

            return Form(
              key: _formKey,
              child: ListView(
                children: <Widget>[
                  AppCard(
                    title: 'Edit Subject Lengkap',
                    subtitle:
                        'Kelola semua properti subject: nama, deskripsi, durasi, attempt limit, dan review.',
                    child: SubjectFormFields(
                      nameController: _nameController,
                      descriptionController: _descriptionController,
                      durationMinutesController: _durationController,
                      showAdvancedFields: true,
                      attemptLimitController: _attemptLimitController,
                      allowReview: _allowReview,
                      onAllowReviewChanged: (value) {
                        setState(() {
                          _allowReview = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Simpan Perubahan',
                    loading: actionState.isUpdating,
                    disabled: actionState.isDeleting,
                    onPressed: _save,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Hapus Subject',
                    variant: AppButtonVariant.danger,
                    loading: actionState.isDeleting,
                    disabled: actionState.isUpdating,
                    onPressed: _deleteSubject,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Kembali ke Subject Management',
                    variant: AppButtonVariant.secondary,
                    disabled: actionState.isUpdating || actionState.isDeleting,
                    onPressed: () => context.go('/admin/subjects'),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const AppCard(
            title: 'Gagal memuat subject',
            subtitle: 'Data subject belum bisa dimuat. Coba lagi sebentar.',
          ),
        ),
      ),
    );
  }
}
