import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/spacing.dart';

enum WarningBannerType { info, warning, danger }

class WarningBanner extends StatelessWidget {
  const WarningBanner({
    super.key,
    required this.type,
    required this.message,
    required this.isVisible,
  });

  final WarningBannerType type;
  final String message;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    final palette = _palette(context, type);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: palette.background,
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(palette.icon, color: palette.textColor, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.textColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  _BannerPalette _palette(BuildContext context, WarningBannerType type) {
    final scheme = Theme.of(context).colorScheme;
    switch (type) {
      case WarningBannerType.info:
        return _BannerPalette(
          background: scheme.primary.withValues(alpha: 0.1),
          border: scheme.primary.withValues(alpha: 0.28),
          textColor: scheme.primary,
          icon: Icons.info_outline,
        );
      case WarningBannerType.warning:
        return _BannerPalette(
          background: AppColors.warning.withValues(alpha: 0.12),
          border: AppColors.warning.withValues(alpha: 0.32),
          textColor: AppColors.warning,
          icon: Icons.warning_amber_rounded,
        );
      case WarningBannerType.danger:
        return _BannerPalette(
          background: AppColors.danger.withValues(alpha: 0.11),
          border: AppColors.danger.withValues(alpha: 0.3),
          textColor: AppColors.danger,
          icon: Icons.error_outline,
        );
    }
  }
}

class _BannerPalette {
  const _BannerPalette({
    required this.background,
    required this.border,
    required this.textColor,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color textColor;
  final IconData icon;
}
