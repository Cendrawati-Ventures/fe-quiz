import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/spacing.dart';
import '../../../shared/components/app_button.dart';
import '../../../shared/components/app_card.dart';
import '../../../shared/components/app_snackbar.dart';
import '../model/exam_models.dart';
import '../service/classroom_service.dart';
import '../state/admin_class_state.dart';
import '../state/exam_state.dart';
import 'widgets/admin_layout.dart';

enum _SubjectFilter { all, selected, unselected }

class AdminClassSubjectAssignmentScreen extends ConsumerStatefulWidget {
  const AdminClassSubjectAssignmentScreen({
    required this.classId,
    super.key,
  });

  final String classId;

  @override
  ConsumerState<AdminClassSubjectAssignmentScreen> createState() =>
      _AdminClassSubjectAssignmentScreenState();
}

class _AdminClassSubjectAssignmentScreenState
    extends ConsumerState<AdminClassSubjectAssignmentScreen> {
  final TextEditingController _searchController = TextEditingController();

  Set<String> _selectedSubjectIds = <String>{};
  bool _initialized = false;
  String _query = '';
  _SubjectFilter _filter = _SubjectFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeSelection(List<String> subjectIds) {
    if (_initialized) {
      return;
    }
    _selectedSubjectIds = subjectIds.toSet();
    _initialized = true;
  }

  List<ApiSubject> _filteredSubjects(List<ApiSubject> subjects) {
    final query = _query.trim().toLowerCase();

    final filtered = subjects.where((subject) {
      final isSelected = _selectedSubjectIds.contains(subject.id);
      if (_filter == _SubjectFilter.selected && !isSelected) {
        return false;
      }
      if (_filter == _SubjectFilter.unselected && isSelected) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final name = subject.name.trim().toLowerCase();
      final description = subject.description.trim().toLowerCase();
      return name.contains(query) || description.contains(query);
    }).toList();

    filtered.sort((left, right) => left.name.compareTo(right.name));
    return filtered;
  }

  void _toggleSubject(String subjectId, bool selected) {
    setState(() {
      if (selected) {
        _selectedSubjectIds.add(subjectId);
      } else {
        _selectedSubjectIds.remove(subjectId);
      }
    });
  }

  void _selectAll(List<ApiSubject> filteredSubjects) {
    setState(() {
      for (final subject in filteredSubjects) {
        _selectedSubjectIds.add(subject.id);
      }
    });
  }

  void _clearAll(List<ApiSubject> filteredSubjects) {
    setState(() {
      for (final subject in filteredSubjects) {
        _selectedSubjectIds.remove(subject.id);
      }
    });
  }

  Future<void> _saveAssignments() async {
    final detail =
        await ref.read(adminClassActionProvider.notifier).saveSubjectAssignments(
              classId: widget.classId,
              subjectIds: _selectedSubjectIds.toList(),
            );

    if (!mounted) {
      return;
    }

    if (detail != null) {
      setState(() {
        _selectedSubjectIds = detail.subjectIds.toSet();
      });
      AppSnackBar.success(context, 'Akses ujian kelas berhasil diperbarui.');
      return;
    }

    final message = ref.read(adminClassActionProvider).errorMessage ??
        'Pengaturan ujian kelas belum berhasil disimpan.';
    AppSnackBar.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(classDetailProvider(widget.classId));
    final subjectsAsync = ref.watch(subjectListProvider);
    final actionState = ref.watch(adminClassActionProvider);

    return AdminLayout(
      title: 'Atur Ujian Kelas',
      subtitle:
          'Pilih ujian yang dapat diakses kelas ini. Gunakan pencarian dan filter saat data besar.',
      activeSection: AdminSection.classes,
      actions: <Widget>[
        OutlinedButton(
          onPressed: () => context.go('/admin/classes'),
          child: const Text('Kembali'),
        ),
      ],
      child: detailAsync.when(
        data: (detail) {
          _initializeSelection(detail.subjectIds);

          return subjectsAsync.when(
            data: (subjects) {
              final filteredSubjects = _filteredSubjects(subjects);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppCard(
                    title: 'Kelas: ${detail.name}',
                    subtitle:
                        '${_selectedSubjectIds.length} ujian dipilih dari ${subjects.length} total ujian.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            labelText: 'Cari ujian',
                            hintText: 'Cari berdasarkan nama atau deskripsi',
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
                              selected: _filter == _SubjectFilter.all,
                              onSelected: (_) {
                                setState(() {
                                  _filter = _SubjectFilter.all;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Terpilih'),
                              selected: _filter == _SubjectFilter.selected,
                              onSelected: (_) {
                                setState(() {
                                  _filter = _SubjectFilter.selected;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Belum Dipilih'),
                              selected: _filter == _SubjectFilter.unselected,
                              onSelected: (_) {
                                setState(() {
                                  _filter = _SubjectFilter.unselected;
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
                              width: 210,
                              child: AppButton(
                                label: 'Pilih Semua Hasil',
                                variant: AppButtonVariant.secondary,
                                onPressed: filteredSubjects.isEmpty
                                    ? null
                                    : () => _selectAll(filteredSubjects),
                              ),
                            ),
                            SizedBox(
                              width: 210,
                              child: AppButton(
                                label: 'Kosongkan Hasil',
                                variant: AppButtonVariant.ghost,
                                onPressed: filteredSubjects.isEmpty
                                    ? null
                                    : () => _clearAll(filteredSubjects),
                              ),
                            ),
                          ],
                        ),
                      ],
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
                              'Daftar Ujian (${filteredSubjects.length})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          Expanded(
                            child: filteredSubjects.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Tidak ada ujian sesuai pencarian/filter.',
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: filteredSubjects.length,
                                    itemBuilder: (context, index) {
                                      final subject = filteredSubjects[index];
                                      final selected =
                                          _selectedSubjectIds.contains(subject.id);

                                      return CheckboxListTile(
                                        dense: true,
                                        value: selected,
                                        title: Text(subject.name),
                                        subtitle: Text(
                                          'Durasi ${subject.durationMinutes} menit | Batas ${subject.attemptLimit}x'
                                          '${subject.description.trim().isNotEmpty ? ' | ${subject.description.trim()}' : ''}',
                                        ),
                                        onChanged: (value) {
                                          _toggleSubject(
                                            subject.id,
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
                          label: 'Simpan Ujian',
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
              title: 'Gagal memuat ujian',
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
