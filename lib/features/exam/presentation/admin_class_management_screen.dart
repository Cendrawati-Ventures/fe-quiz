import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_button.dart';
import '../../../shared/components/app_card.dart';
import '../../../shared/components/app_snackbar.dart';
import '../model/classroom_models.dart';
import '../service/classroom_service.dart';
import '../service/student_account_service.dart';
import '../state/admin_class_state.dart';
import '../state/exam_state.dart';
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
            'Siswa di kelas ini akan dilepas dari kelas dan pengaturan akses mapel kelas ini juga hilang.',
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

  Future<void> _showManageAssignmentsDialog(
    BuildContext context, {
    required String classId,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ClassAssignmentDialog(classId: classId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classListProvider);

    return AdminLayout(
      title: 'Kelola Kelas',
      subtitle: 'Atur kelas, anggota siswa, dan akses mata pelajaran.',
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
                          'Siswa: ${item.studentCount} orang\nAkses mata pelajaran: ${item.subjectCount} mapel',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          SizedBox(
                            width: 220,
                            child: AppButton(
                              label: 'Atur Anggota & Akses',
                              variant: AppButtonVariant.secondary,
                              onPressed: () => _showManageAssignmentsDialog(
                                context,
                                classId: item.id,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 150,
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
                            width: 120,
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

class _ClassAssignmentDialog extends ConsumerStatefulWidget {
  const _ClassAssignmentDialog({required this.classId});

  final String classId;

  @override
  ConsumerState<_ClassAssignmentDialog> createState() =>
      _ClassAssignmentDialogState();
}

class _ClassAssignmentDialogState extends ConsumerState<_ClassAssignmentDialog> {
  Set<String> _selectedStudentIds = <String>{};
  Set<String> _selectedSubjectIds = <String>{};
  bool _initialized = false;

  void _initSelection(AdminClassDetail detail) {
    if (_initialized) {
      return;
    }

    _selectedStudentIds = detail.studentIds.toSet();
    _selectedSubjectIds = detail.subjectIds.toSet();
    _initialized = true;
  }

  Future<void> _saveAssignments() async {
    final detail = await ref.read(adminClassActionProvider.notifier).saveAssignments(
          classId: widget.classId,
          studentIds: _selectedStudentIds.toList(),
          subjectIds: _selectedSubjectIds.toList(),
        );

    if (!mounted) {
      return;
    }

    if (detail != null) {
      AppSnackBar.success(context, 'Pengaturan kelas berhasil disimpan.');
      Navigator.of(context).pop();
      return;
    }

    final message = ref.read(adminClassActionProvider).errorMessage ??
        'Pengaturan kelas belum berhasil disimpan.';
    AppSnackBar.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(classDetailProvider(widget.classId));
    final studentsAsync = ref.watch(studentAccountsProvider);
    final subjectsAsync = ref.watch(subjectListProvider);
    final actionState = ref.watch(adminClassActionProvider);

    return AlertDialog(
      title: const Text('Atur Anggota & Akses Mapel'),
      content: SizedBox(
        width: 760,
        child: detailAsync.when(
          data: (detail) {
            _initSelection(detail);
            return studentsAsync.when(
              data: (students) {
                return subjectsAsync.when(
                  data: (subjects) {
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Kelas: ${detail.name}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text('Pilih siswa yang menjadi anggota kelas ini.'),
                          const SizedBox(height: AppSpacing.xs),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: ListView(
                              shrinkWrap: true,
                              children: students.map((student) {
                                final checked = _selectedStudentIds.contains(student.id);
                                final label = student.fullName?.trim().isNotEmpty == true
                                    ? student.fullName!.trim()
                                    : student.username;
                                return CheckboxListTile(
                                  dense: true,
                                  value: checked,
                                  title: Text(label),
                                  subtitle: Text('username: ${student.username}'),
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedStudentIds.add(student.id);
                                      } else {
                                        _selectedStudentIds.remove(student.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text('Pilih mata pelajaran yang boleh diakses kelas ini.'),
                          const SizedBox(height: AppSpacing.xs),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: ListView(
                              shrinkWrap: true,
                              children: subjects.map((subject) {
                                final checked = _selectedSubjectIds.contains(subject.id);
                                return CheckboxListTile(
                                  dense: true,
                                  value: checked,
                                  title: Text(subject.name),
                                  subtitle: Text(
                                      'Durasi ${subject.durationMinutes} menit | Batas ${subject.attemptLimit}x'),
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedSubjectIds.add(subject.id);
                                      } else {
                                        _selectedSubjectIds.remove(subject.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text(error.toString()),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text(error.toString()),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text(error.toString()),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: actionState.isSavingAssignments
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
        FilledButton(
          onPressed: actionState.isSavingAssignments ? null : _saveAssignments,
          child: actionState.isSavingAssignments
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan Pengaturan'),
        ),
      ],
    );
  }
}
