import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_button.dart';
import '../../../shared/components/app_card.dart';
import '../../../shared/components/app_snackbar.dart';
import '../model/student_account.dart';
import '../service/classroom_service.dart';
import '../service/student_account_service.dart';
import '../state/admin_class_state.dart';
import 'widgets/admin_layout.dart';

enum _StudentFilter { all, selected, unselected }

class AdminClassStudentAssignmentScreen extends ConsumerStatefulWidget {
  const AdminClassStudentAssignmentScreen({
    required this.classId,
    super.key,
  });

  final String classId;

  @override
  ConsumerState<AdminClassStudentAssignmentScreen> createState() =>
      _AdminClassStudentAssignmentScreenState();
}

class _AdminClassStudentAssignmentScreenState
    extends ConsumerState<AdminClassStudentAssignmentScreen> {
  final TextEditingController _searchController = TextEditingController();

  Set<String> _selectedStudentIds = <String>{};
  bool _initialized = false;
  String _query = '';
  _StudentFilter _filter = _StudentFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeSelection(List<String> studentIds) {
    if (_initialized) {
      return;
    }
    _selectedStudentIds = studentIds.toSet();
    _initialized = true;
  }

  List<StudentAccount> _filteredStudents(List<StudentAccount> students) {
    final query = _query.trim().toLowerCase();

    final filtered = students.where((student) {
      final isSelected = _selectedStudentIds.contains(student.id);
      if (_filter == _StudentFilter.selected && !isSelected) {
        return false;
      }
      if (_filter == _StudentFilter.unselected && isSelected) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final fullName = student.fullName?.trim().toLowerCase() ?? '';
      final username = student.username.trim().toLowerCase();
      final rollNumber = student.rollNumber?.trim().toLowerCase() ?? '';
      final className = student.className?.trim().toLowerCase() ?? '';

      return fullName.contains(query) ||
          username.contains(query) ||
          rollNumber.contains(query) ||
          className.contains(query);
    }).toList();

    filtered.sort((left, right) {
      final leftName = left.fullName?.trim().isNotEmpty == true
          ? left.fullName!.trim().toLowerCase()
          : left.username.trim().toLowerCase();
      final rightName = right.fullName?.trim().isNotEmpty == true
          ? right.fullName!.trim().toLowerCase()
          : right.username.trim().toLowerCase();
      return leftName.compareTo(rightName);
    });

    return filtered;
  }

  void _toggleStudent(String studentId, bool selected) {
    setState(() {
      if (selected) {
        _selectedStudentIds.add(studentId);
      } else {
        _selectedStudentIds.remove(studentId);
      }
    });
  }

  void _selectAll(List<StudentAccount> filteredStudents) {
    setState(() {
      for (final student in filteredStudents) {
        _selectedStudentIds.add(student.id);
      }
    });
  }

  void _clearAll(List<StudentAccount> filteredStudents) {
    setState(() {
      for (final student in filteredStudents) {
        _selectedStudentIds.remove(student.id);
      }
    });
  }

  Future<void> _saveAssignments() async {
    final detail = await ref
        .read(adminClassActionProvider.notifier)
        .saveStudentAssignments(
          classId: widget.classId,
          studentIds: _selectedStudentIds.toList(),
        );

    if (!mounted) {
      return;
    }

    if (detail != null) {
      setState(() {
        _selectedStudentIds = detail.studentIds.toSet();
      });
      AppSnackBar.success(context, 'Anggota kelas berhasil diperbarui.');
      return;
    }

    final message = ref.read(adminClassActionProvider).errorMessage ??
        'Pengaturan anggota kelas belum berhasil disimpan.';
    AppSnackBar.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(classDetailProvider(widget.classId));
    final studentsAsync = ref.watch(studentAccountsProvider);
    final actionState = ref.watch(adminClassActionProvider);
    final topSectionMaxHeight = (MediaQuery.sizeOf(context).height * 0.32)
        .clamp(120.0, 260.0)
        .toDouble();

    return AdminLayout(
      title: 'Atur Anggota Kelas',
      subtitle:
          'Pilih siswa untuk kelas ini. Gunakan pencarian dan filter saat data besar.',
      activeSection: AdminSection.classes,
      child: detailAsync.when(
        data: (detail) {
          _initializeSelection(detail.studentIds);

          return studentsAsync.when(
            data: (students) {
              final filteredStudents = _filteredStudents(students);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: topSectionMaxHeight),
                    child: SingleChildScrollView(
                      primary: false,
                      child: AppCard(
                        title: 'Kelas: ${detail.name}',
                        subtitle:
                            '${_selectedStudentIds.length} siswa dipilih dari ${students.length} total siswa.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                labelText: 'Cari siswa',
                                hintText:
                                    'Cari berdasarkan nama, username, no absen, atau kelas',
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _query = value;
                                });
                              },
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: <Widget>[
                                ChoiceChip(
                                  label: const Text('Semua'),
                                  selected: _filter == _StudentFilter.all,
                                  onSelected: (_) {
                                    setState(() {
                                      _filter = _StudentFilter.all;
                                    });
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('Terpilih'),
                                  selected: _filter == _StudentFilter.selected,
                                  onSelected: (_) {
                                    setState(() {
                                      _filter = _StudentFilter.selected;
                                    });
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('Belum Dipilih'),
                                  selected:
                                      _filter == _StudentFilter.unselected,
                                  onSelected: (_) {
                                    setState(() {
                                      _filter = _StudentFilter.unselected;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: <Widget>[
                                SizedBox(
                                  width: 200,
                                  child: AppButton(
                                    label: 'Pilih Semua Hasil',
                                    variant: AppButtonVariant.secondary,
                                    onPressed: filteredStudents.isEmpty
                                        ? null
                                        : () => _selectAll(filteredStudents),
                                  ),
                                ),
                                SizedBox(
                                  width: 200,
                                  child: AppButton(
                                    label: 'Kosongkan Hasil',
                                    variant: AppButtonVariant.ghost,
                                    onPressed: filteredStudents.isEmpty
                                        ? null
                                        : () => _clearAll(filteredStudents),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(
                              'Daftar Siswa (${filteredStudents.length})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          Expanded(
                            child: filteredStudents.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Tidak ada siswa sesuai pencarian/filter.',
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: filteredStudents.length,
                                    itemBuilder: (context, index) {
                                      final student = filteredStudents[index];
                                      final selected = _selectedStudentIds
                                          .contains(student.id);
                                      final fullName =
                                          student.fullName?.trim().isNotEmpty ==
                                                  true
                                              ? student.fullName!.trim()
                                              : student.username;
                                      final rollNumber =
                                          student.rollNumber?.trim() ?? '';
                                      final studentClass =
                                          student.className?.trim() ?? '';

                                      return CheckboxListTile(
                                        dense: true,
                                        value: selected,
                                        title: Text(fullName),
                                        subtitle: Text(
                                          'username: ${student.username}'
                                          '${rollNumber.isNotEmpty ? ' | absen: $rollNumber' : ''}'
                                          '${studentClass.isNotEmpty ? ' | kelas saat ini: $studentClass' : ''}',
                                        ),
                                        onChanged: (value) {
                                          _toggleStudent(
                                            student.id,
                                            value == true,
                                          );
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: AppButton(
                          label: 'Kembali ke Kelas',
                          variant: AppButtonVariant.ghost,
                          onPressed: () => context.go('/admin/classes'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          label: 'Simpan Anggota',
                          loading: actionState.isSavingAssignments,
                          onPressed: actionState.isSavingAssignments
                              ? null
                              : _saveAssignments,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AppCard(
              title: 'Gagal memuat siswa',
              subtitle: error.toString(),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppCard(
          title: 'Gagal memuat detail kelas',
          subtitle: error.toString(),
        ),
      ),
    );
  }
}
