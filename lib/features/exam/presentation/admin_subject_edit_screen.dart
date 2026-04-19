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

class _AdminSubjectEditScreenState
    extends ConsumerState<AdminSubjectEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _attemptLimitController = TextEditingController();
  bool _allowReview = false;
  DateTime? _publishAt;
  DateTime? _closeAt;
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
    _publishAt = subject.publishAt?.toLocal();
    _closeAt = subject.closeAt?.toLocal();
    _initialized = true;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final durationMinutes = int.parse(_durationController.text.trim());
    final attemptLimit = int.parse(_attemptLimitController.text.trim());
    final publishAt = _publishAt;
    final closeAt = _closeAt;
    if (publishAt == null || closeAt == null) {
      AppSnackBar.error(context, 'Waktu publish dan close ujian wajib diisi.');
      return;
    }
    if (!closeAt.isAfter(publishAt)) {
      AppSnackBar.error(context, 'Waktu close harus setelah waktu publish.');
      return;
    }

    final updated = await ref.read(adminSubjectActionProvider.notifier).update(
          id: widget.subjectId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          durationMinutes: durationMinutes,
          attemptLimit: attemptLimit,
          allowReview: _allowReview,
          publishAt: publishAt,
          closeAt: closeAt,
        );

    if (!mounted) {
      return;
    }

    if (updated != null) {
      AppSnackBar.success(context, 'Ujian berhasil diperbarui.');
      context.go('/admin/subjects');
      return;
    }

    final error = ref.read(adminSubjectActionProvider).errorMessage;
    AppSnackBar.error(context, error ?? 'Gagal memperbarui ujian.');
  }

  Future<void> _deleteSubject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Ujian'),
          content: const Text(
            'Yakin ingin menghapus ujian ini? Tindakan ini tidak bisa dibatalkan.',
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

    final deleted = await ref
        .read(adminSubjectActionProvider.notifier)
        .delete(widget.subjectId);

    if (!mounted) {
      return;
    }

    if (deleted) {
      AppSnackBar.success(context, 'Ujian berhasil dihapus.');
      context.go('/admin/subjects');
      return;
    }

    final error = ref.read(adminSubjectActionProvider).errorMessage;
    AppSnackBar.error(context, error ?? 'Gagal menghapus ujian.');
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectListProvider);
    final actionState = ref.watch(adminSubjectActionProvider);

    return AdminLayout(
      title: 'Ubah Ujian',
      subtitle: 'Perbarui data ujian secara lengkap.',
      activeSection: AdminSection.subjects,
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
                  title: 'Ujian tidak ditemukan',
                  subtitle:
                      'Data ujian belum tersedia. Silakan kembali lalu muat ulang daftar.',
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Kembali ke Kelola Ujian',
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
                  title: 'Ubah Data Ujian',
                  subtitle:
                      'Atur nama, deskripsi, jadwal publish-close, durasi, batas percobaan, dan izin tinjau jawaban.',
                  child: SubjectFormFields(
                    nameController: _nameController,
                    descriptionController: _descriptionController,
                    durationMinutesController: _durationController,
                    publishAt: _publishAt,
                    closeAt: _closeAt,
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
                  label: 'Hapus Ujian',
                  variant: AppButtonVariant.danger,
                  loading: actionState.isDeleting,
                  disabled: actionState.isUpdating,
                  onPressed: _deleteSubject,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Kembali ke Kelola Ujian',
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
          title: 'Gagal memuat ujian',
          subtitle: 'Data ujian belum bisa dimuat. Coba lagi sebentar.',
        ),
      ),
    );
  }
}
