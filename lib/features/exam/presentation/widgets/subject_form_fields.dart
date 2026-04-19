import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/spacing.dart';

class SubjectFormFields extends StatelessWidget {
  const SubjectFormFields({
    required this.nameController,
    required this.descriptionController,
    required this.durationMinutesController,
    required this.publishAt,
    required this.closeAt,
    required this.onPublishAtChanged,
    required this.onCloseAtChanged,
    super.key,
    this.showAdvancedFields = false,
    this.attemptLimitController,
    this.allowReview = false,
    this.onAllowReviewChanged,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController durationMinutesController;
  final DateTime? publishAt;
  final DateTime? closeAt;
  final ValueChanged<DateTime> onPublishAtChanged;
  final ValueChanged<DateTime> onCloseAtChanged;
  final bool showAdvancedFields;
  final TextEditingController? attemptLimitController;
  final bool allowReview;
  final ValueChanged<bool>? onAllowReviewChanged;

  Future<DateTime?> _pickDateTime({
    required BuildContext context,
    required DateTime? initial,
  }) async {
    final now = DateTime.now();
    final base = initial ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (pickedDate == null) {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nama Ujian',
            hintText: 'Contoh: Ujian Matematika Dasar',
          ),
          textInputAction: TextInputAction.next,
          validator: _validateName,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: descriptionController,
          decoration: const InputDecoration(
            labelText: 'Deskripsi',
            hintText: 'Ringkasan ujian',
          ),
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          validator: _validateDescription,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: durationMinutesController,
          decoration: const InputDecoration(
            labelText: 'Durasi (menit)',
            hintText: 'Contoh: 90',
          ),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: false,
            signed: false,
          ),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          textInputAction: TextInputAction.next,
          validator: _validateDuration,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            SizedBox(
              width: 280,
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await _pickDateTime(
                    context: context,
                    initial: publishAt,
                  );
                  if (picked != null) {
                    onPublishAtChanged(picked);
                  }
                },
                child: Text(
                  publishAt == null
                      ? 'Pilih Waktu Publish'
                      : 'Publish: ${_formatDateTime(publishAt)}',
                ),
              ),
            ),
            SizedBox(
              width: 280,
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await _pickDateTime(
                    context: context,
                    initial: closeAt,
                  );
                  if (picked != null) {
                    onCloseAtChanged(picked);
                  }
                },
                child: Text(
                  closeAt == null
                      ? 'Pilih Waktu Close'
                      : 'Close: ${_formatDateTime(closeAt)}',
                ),
              ),
            ),
          ],
        ),
        if (showAdvancedFields && attemptLimitController != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: attemptLimitController,
            decoration: const InputDecoration(
              labelText: 'Batas Percobaan',
              hintText: 'Contoh: 1',
            ),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: false,
              signed: false,
            ),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            textInputAction: TextInputAction.done,
            validator: _validateAttemptLimit,
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: allowReview,
            title: const Text('Izinkan Tinjau Jawaban'),
            subtitle: const Text(
              'Jika aktif, siswa dapat melihat ringkasan jawabannya.',
            ),
            onChanged: onAllowReviewChanged,
          ),
        ],
      ],
    );
  }

  static String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Nama ujian wajib diisi';
    }
    if (text.length < 2) {
      return 'Nama ujian minimal 2 karakter';
    }
    if (text.length > 150) {
      return 'Nama ujian maksimal 150 karakter';
    }
    return null;
  }

  static String? _validateDescription(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Deskripsi wajib diisi';
    }
    if (text.length < 3) {
      return 'Deskripsi minimal 3 karakter';
    }
    if (text.length > 1000) {
      return 'Deskripsi maksimal 1000 karakter';
    }
    return null;
  }

  static String? _validateDuration(String? value) {
    final text = value?.trim() ?? '';
    final number = int.tryParse(text);
    if (number == null) {
      return 'Durasi harus berupa angka';
    }
    if (number <= 0) {
      return 'Durasi harus lebih dari 0';
    }
    return null;
  }

  static String? _validateAttemptLimit(String? value) {
    final text = value?.trim() ?? '';
    final number = int.tryParse(text);
    if (number == null) {
      return 'Batas percobaan harus berupa angka';
    }
    if (number <= 0) {
      return 'Batas percobaan harus lebih dari 0';
    }
    return null;
  }
}
