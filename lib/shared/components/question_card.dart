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
          ],
        ),
      ),
    );
  }
}
