import 'package:flutter/material.dart';

import '../../app/theme/spacing.dart';

class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.current,
    required this.total,
    required this.value,
  });

  final int current;
  final int total;
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Progress $current/$total',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: scheme.primaryContainer.withValues(alpha: 0.45),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 10,
              backgroundColor: Colors.white,
              color: scheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
