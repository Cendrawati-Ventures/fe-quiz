import 'package:flutter/material.dart';

import '../../app/theme/typography.dart';

class TimerWidget extends StatelessWidget {
  const TimerWidget({
    super.key,
    required this.remainingSeconds,
    this.isWarning = false,
  });

  final int remainingSeconds;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final hours = remainingSeconds ~/ 3600;
    final minutes = (remainingSeconds % 3600) ~/ 60;
    final seconds = remainingSeconds % 60;
    final text = [
      hours.toString().padLeft(2, '0'),
      minutes.toString().padLeft(2, '0'),
      seconds.toString().padLeft(2, '0'),
    ].join(':');

    return Text(
      text,
      style: AppTypography.timer.copyWith(
        color: isWarning ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }
}
