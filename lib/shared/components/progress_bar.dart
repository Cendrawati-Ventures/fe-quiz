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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Progress $current/$total',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: value.clamp(0, 1)),
        ),
      ],
    );
  }
}
