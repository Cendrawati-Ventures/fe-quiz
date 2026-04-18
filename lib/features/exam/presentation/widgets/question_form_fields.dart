import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/spacing.dart';

class QuestionFormFields extends StatelessWidget {
  const QuestionFormFields({
    required this.questionTextController,
    required this.weightController,
    required this.optionControllers,
    required this.correctAnswerIndex,
    required this.onCorrectAnswerChanged,
    super.key,
  });

  final TextEditingController questionTextController;
  final TextEditingController weightController;
  final List<TextEditingController> optionControllers;
  final int? correctAnswerIndex;
  final ValueChanged<int?> onCorrectAnswerChanged;

  @override
  Widget build(BuildContext context) {
    final labels = <String>['A', 'B', 'C', 'D'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          controller: questionTextController,
          decoration: const InputDecoration(
            labelText: 'Teks Soal',
            hintText: 'Tulis pertanyaan di sini',
          ),
          minLines: 2,
          maxLines: 6,
          validator: validateQuestionText,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: weightController,
          decoration: const InputDecoration(
            labelText: 'Poin Soal',
            hintText: 'Contoh: 10',
          ),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: false,
            signed: false,
          ),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          validator: validateWeight,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Pilihan Jawaban (4 opsi)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Pilih satu jawaban yang benar menggunakan radio button.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        RadioGroup<int>(
          groupValue: correctAnswerIndex,
          onChanged: onCorrectAnswerChanged,
          child: Column(
            children: <Widget>[
              for (var index = 0; index < 4; index++) ...<Widget>[
                Row(
                  children: <Widget>[
                    Radio<int>(value: index),
                    Expanded(
                      child: TextFormField(
                        controller: optionControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Opsi ${labels[index]}',
                          hintText: 'Isi teks opsi ${labels[index]}',
                        ),
                        validator: validateOptionText,
                      ),
                    ),
                  ],
                ),
                if (index < 3) const SizedBox(height: AppSpacing.xs),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String? validateQuestionText(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Teks soal wajib diisi.';
    }
    if (text.length < 3) {
      return 'Teks soal minimal 3 karakter.';
    }
    return null;
  }

  static String? validateWeight(String? value) {
    final text = value?.trim() ?? '';
    final number = int.tryParse(text);
    if (number == null) {
      return 'Poin harus berupa angka.';
    }
    if (number <= 0) {
      return 'Poin harus lebih dari 0.';
    }
    if (number > 100) {
      return 'Poin maksimal 100.';
    }
    return null;
  }

  static String? validateOptionText(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Opsi wajib diisi.';
    }
    return null;
  }
}
