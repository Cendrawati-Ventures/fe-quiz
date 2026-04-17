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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Soal ${questionIndex + 1} dari $totalQuestion',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(question.text, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
