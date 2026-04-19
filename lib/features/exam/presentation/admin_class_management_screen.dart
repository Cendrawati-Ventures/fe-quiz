import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_button.dart';
import '../../../shared/components/app_card.dart';
import '../../../shared/components/app_snackbar.dart';
import '../model/classroom_models.dart';
import '../service/classroom_service.dart';
import '../state/admin_class_state.dart';
import 'widgets/admin_layout.dart';

class AdminClassManagementScreen extends ConsumerWidget {
  const AdminClassManagementScreen({super.key});

  Future<void> _showCreateClassDialog(BuildContext context) async {
    final created = await showDialog<AdminClassSummary>(
      context: context,
      builder: (_) => const _CreateClassDialog(),
    );

    if (!context.mounted || created == null) {
      return;
    }

    AppSnackBar.success(context, 'Kelas ${created.name} berhasil dibuat.');
  }

  Future<void> _showRenameClassDialog(
    BuildContext context, {
    required AdminClassSummary classRoom,
  }) async {
    final renamed = await showDialog<AdminClassSummary>(
      context: context,
      builder: (_) => _RenameClassDialog(classRoom: classRoom),
    );

    if (!context.mounted || renamed == null) {
      return;
    }

    AppSnackBar.success(context, 'Nama kelas berhasil diperbarui.');
  }

  Future<void> _showDeleteClassDialog(
    BuildContext context,
    WidgetRef ref, {
    required AdminClassSummary classRoom,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Kelas'),
          content: Text(
            'Kelas "${classRoom.name}" akan dihapus.\n\n'
            'Siswa di kelas ini akan dilepas dari kelas dan pengaturan akses ujian kelas ini juga hilang.',
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

    if (confirmed != true || !context.mounted) {
      return;
    }

    final deleted =
        await ref.read(adminClassActionProvider.notifier).deleteClass(classRoom.id);
    if (!context.mounted) {
      return;
    }

    if (deleted) {
      AppSnackBar.success(context, 'Kelas berhasil dihapus.');
      return;
    }

    final message = ref.read(adminClassActionProvider).errorMessage ??
        'Kelas belum berhasil dihapus.';
    AppSnackBar.error(context, message);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classListProvider);

    return AdminLayout(
      title: 'Kelola Kelas',
      subtitle: 'Atur kelas, anggota siswa, dan akses ujian.',
      activeSection: AdminSection.classes,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppButton(
            label: 'Tambah Kelas',
            onPressed: () => _showCreateClassDialog(context),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: classesAsync.when(
              data: (classes) {
                if (classes.isEmpty) {
                  return const AppCard(
                    title: 'Belum ada kelas',
                    subtitle: 'Buat kelas baru untuk mulai mengelola akses ujian.',
                  );
                }

                return ListView.separated(
                  itemCount: classes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = classes[index];
                    return AppCard(
                      title: item.name,
                      subtitle:
                          'Siswa: ${item.studentCount} orang\nAkses ujian: ${item.subjectCount} ujian',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          SizedBox(
                            width: 170,
                            child: AppButton(
                              label: 'Atur Anggota',
                              variant: AppButtonVariant.secondary,
                              onPressed: () =>
                                  context.go('/admin/classes/${item.id}/students'),
                            ),
                          ),
                          SizedBox(
                            width: 210,
                            child: AppButton(
                              label: 'Atur Ujian',
                              variant: AppButtonVariant.secondary,
                              onPressed: () =>
                                  context.go('/admin/classes/${item.id}/subjects'),
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: AppButton(
                              label: 'Ubah Nama',
                              variant: AppButtonVariant.secondary,
                              onPressed: () => _showRenameClassDialog(
                                context,
                                classRoom: item,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: AppButton(
                              label: 'Hapus',
                              variant: AppButtonVariant.danger,
                              onPressed: () => _showDeleteClassDialog(
                                context,
                                ref,
                                classRoom: item,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => AppCard(
                title: 'Gagal memuat kelas',
                subtitle: error.toString(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateClassDialog extends ConsumerStatefulWidget {
  const _CreateClassDialog();

  @override
  ConsumerState<_CreateClassDialog> createState() => _CreateClassDialogState();
}

class _CreateClassDialogState extends ConsumerState<_CreateClassDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final created = await ref
        .read(adminClassActionProvider.notifier)
        .createClass(_nameController.text.trim());

    if (!mounted) {
      return;
    }

    if (created != null) {
      Navigator.of(context).pop(created);
      return;
    }

    final message =
        ref.read(adminClassActionProvider).errorMessage ?? 'Kelas gagal dibuat.';
    AppSnackBar.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(adminClassActionProvider);

    return AlertDialog(
      title: const Text('Tambah Kelas'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Nama Kelas',
            hintText: 'Contoh: XII IPA 1',
          ),
          validator: (value) {
            final text = (value ?? '').trim();
            if (text.isEmpty) {
              return 'Nama kelas wajib diisi';
            }
            if (text.length > 80) {
              return 'Nama kelas maksimal 80 karakter';
            }
            return null;
          },
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
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

class _RenameClassDialog extends ConsumerStatefulWidget {
  const _RenameClassDialog({required this.classRoom});

  final AdminClassSummary classRoom;

  @override
  ConsumerState<_RenameClassDialog> createState() => _RenameClassDialogState();
}

class _RenameClassDialogState extends ConsumerState<_RenameClassDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.classRoom.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final updated = await ref.read(adminClassActionProvider.notifier).updateClass(
          classId: widget.classRoom.id,
          name: _nameController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    if (updated != null) {
      Navigator.of(context).pop(updated);
      return;
    }

    final message = ref.read(adminClassActionProvider).errorMessage ??
        'Nama kelas gagal diperbarui.';
    AppSnackBar.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(adminClassActionProvider);

    return AlertDialog(
      title: const Text('Ubah Nama Kelas'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Nama Kelas',
          ),
          validator: (value) {
            final text = (value ?? '').trim();
            if (text.isEmpty) {
              return 'Nama kelas wajib diisi';
            }
            if (text.length > 80) {
              return 'Nama kelas maksimal 80 karakter';
            }
            return null;
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed:
              actionState.isUpdating ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: actionState.isUpdating ? null : _submit,
          child: actionState.isUpdating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
