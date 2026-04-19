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
    final statusText = isOnline ? 'Terhubung' : 'Terputus';
    final syncLabel = _syncStatusLabel(syncStatus);

    return Chip(
      backgroundColor: statusColor.withValues(alpha: 0.14),
      side: BorderSide(color: statusColor.withValues(alpha: 0.35)),
      avatar: CircleAvatar(backgroundColor: statusColor, radius: 5),
      label: Text(
        '$statusText | $syncLabel',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  String _syncStatusLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'synced':
        return 'Tersimpan';
      case 'pending':
        return 'Menunggu Kirim';
      case 'retrying':
        return 'Mencoba Lagi';
      default:
        return 'Memproses';
    }
  }
}
