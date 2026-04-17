import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';

class ConnectionChip extends StatelessWidget {
  const ConnectionChip({
    super.key,
    required this.isOnline,
    required this.syncStatus,
  });

  final bool isOnline;
  final String syncStatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = isOnline ? AppColors.success : AppColors.warning;
    final statusText = isOnline ? 'Online' : 'Offline';

    return Chip(
      backgroundColor: statusColor.withValues(alpha: 0.14),
      side: BorderSide(color: statusColor.withValues(alpha: 0.35)),
      avatar: CircleAvatar(backgroundColor: statusColor, radius: 5),
      label: Text(
        '$statusText | $syncStatus',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
