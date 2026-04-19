import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/spacing.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/components/app_button.dart';
import '../../../shared/components/app_card.dart';
import '../../../shared/components/app_snackbar.dart';
import '../model/exam_models.dart';
import '../state/exam_state.dart';
import 'widgets/admin_layout.dart';

class AdminExamManagementScreen extends ConsumerStatefulWidget {
  const AdminExamManagementScreen({super.key});

  @override
  ConsumerState<AdminExamManagementScreen> createState() =>
      _AdminExamManagementScreenState();
}

class _AdminExamManagementScreenState
    extends ConsumerState<AdminExamManagementScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  DateTime? _startAt;
  DateTime? _endAt;
  bool _publishAfterCreate = true;
  bool _isSubmitting = false;
  String? _publishingExamId;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime({required DateTime? initial}) async {
    final now = DateTime.now();
    final base = initial ?? now.add(const Duration(minutes: 10));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (pickedDate == null || !mounted) {
      return null;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (pickedTime == null) {
      return null;
    }

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

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

  String _examStatus(ApiExam exam) {
    final now = DateTime.now().toUtc();
    if (!exam.isPublished) {
      return 'Draft (belum publish)';
    }
    if (now.isBefore(exam.startTime.toUtc())) {
      return 'Terjadwal (belum mulai)';
    }
    if (now.isAfter(exam.endTime.toUtc())) {
      return 'Selesai (closed by time)';
    }
    return 'Aktif';
  }

  Future<void> _submitCreate() async {
    if (_isSubmitting) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_startAt == null || _endAt == null) {
      AppSnackBar.error(context, 'Waktu publish dan close wajib diisi.');
      return;
    }
    if (!_endAt!.isAfter(_startAt!)) {
      AppSnackBar.error(context, 'Waktu close harus setelah waktu publish.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final service = ref.read(examServiceProvider);
    try {
      final created = await service.createExam(
        title: _titleController.text.trim(),
        startTime: _startAt!,
        endTime: _endAt!,
      );

      if (_publishAfterCreate) {
        await service.publishExam(created.id);
      }

      ref.invalidate(examListProvider);
      _titleController.clear();
      _startAt = null;
      _endAt = null;

      if (!mounted) {
        return;
      }
      AppSnackBar.success(context, 'Ujian berhasil dibuat.');
      setState(() {});
    } on ApiError catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.error(context, error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppSnackBar.error(context, 'Ujian belum berhasil dibuat.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _publishExam(ApiExam exam) async {
    if (_publishingExamId != null || exam.isPublished) {
      return;
    }

    setState(() {
      _publishingExamId = exam.id;
    });

    try {
      await ref.read(examServiceProvider).publishExam(exam.id);
      ref.invalidate(examListProvider);
      if (!mounted) {
        return;
      }
      AppSnackBar.success(context, 'Ujian berhasil dipublikasikan.');
    } on ApiError catch (error) {
      if (!mounted) {
        return;
      }
      AppSnackBar.error(context, error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppSnackBar.error(context, 'Ujian belum berhasil dipublikasikan.');
    } finally {
      if (mounted) {
        setState(() {
          _publishingExamId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final examsAsync = ref.watch(examListProvider);

    return AdminLayout(
      title: 'Kelola Ujian',
      subtitle: 'Atur jadwal publish-close dan publikasi ujian.',
      activeSection: AdminSection.exams,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppCard(
            title: 'Buat Jadwal Ujian',
            subtitle:
                'Waktu publish = mulai ujian, waktu close = akhir ujian.',
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Judul Ujian',
                      hintText: 'Contoh: UTS Matematika Kelas 12',
                    ),
                    maxLength: 200,
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.length < 3) {
                        return 'Judul minimal 3 karakter';
                      }
                      if (text.length > 200) {
                        return 'Judul maksimal 200 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      SizedBox(
                        width: 270,
                        child: AppButton(
                          label: _startAt == null
                              ? 'Pilih Waktu Publish'
                              : 'Publish: ${_formatDateTime(_startAt)}',
                          variant: AppButtonVariant.secondary,
                          onPressed: () async {
                            final picked =
                                await _pickDateTime(initial: _startAt);
                            if (picked == null) {
                              return;
                            }
                            setState(() {
                              _startAt = picked;
                              if (_endAt != null && !_endAt!.isAfter(_startAt!)) {
                                _endAt = _startAt!.add(
                                  const Duration(hours: 1),
                                );
                              }
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        width: 270,
                        child: AppButton(
                          label: _endAt == null
                              ? 'Pilih Waktu Close'
                              : 'Close: ${_formatDateTime(_endAt)}',
                          variant: AppButtonVariant.secondary,
                          onPressed: () async {
                            final picked = await _pickDateTime(initial: _endAt);
                            if (picked == null) {
                              return;
                            }
                            setState(() {
                              _endAt = picked;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publish langsung setelah dibuat'),
                    value: _publishAfterCreate,
                    onChanged: (value) {
                      setState(() {
                        _publishAfterCreate = value;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Simpan Ujian',
                    loading: _isSubmitting,
                    onPressed: _submitCreate,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: examsAsync.when(
              data: (exams) {
                if (exams.isEmpty) {
                  return const AppCard(
                    title: 'Belum ada ujian',
                    subtitle: 'Buat ujian baru lalu publish agar tampil ke siswa.',
                  );
                }

                return ListView.separated(
                  itemCount: exams.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final exam = exams[index];
                    final publishing = _publishingExamId == exam.id;
                    final status = _examStatus(exam);

                    return AppCard(
                      title: exam.title,
                      subtitle:
                          'Publish: ${_formatDateTime(exam.startTime)}\nClose: ${_formatDateTime(exam.endTime)}\nStatus: $status',
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: AppButton(
                              label: exam.isPublished
                                  ? 'Sudah Publish'
                                  : 'Publish Sekarang',
                              variant: exam.isPublished
                                  ? AppButtonVariant.ghost
                                  : AppButtonVariant.primary,
                              loading: publishing,
                              disabled: exam.isPublished,
                              onPressed: () => _publishExam(exam),
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
                title: 'Gagal memuat ujian',
                subtitle: error.toString(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
