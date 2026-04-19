import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/theme/spacing.dart';
import '../../features/exam/model/exam_models.dart';

class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.question,
    required this.questionIndex,
    required this.totalQuestion,
  });

  final ApiQuestion question;
  final int questionIndex;
  final int totalQuestion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageBytes = _decodeImageData(question.imageData);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: scheme.secondaryContainer.withValues(alpha: 0.75),
              ),
              child: Text(
                'Soal ${questionIndex + 1} dari $totalQuestion',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              question.text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
            ),
            if (imageBytes != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  imageBytes,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Uint8List? _decodeImageData(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }

    final match =
        RegExp(r'^data:image\/[a-zA-Z0-9.+-]+;base64,(.+)$').firstMatch(value);
    if (match == null) {
      return null;
    }

    final encoded = match.group(1);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }
}
