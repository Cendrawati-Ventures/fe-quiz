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

    final palette = _palette(type);

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

  _BannerPalette _palette(WarningBannerType type) {
    switch (type) {
      case WarningBannerType.info:
        return const _BannerPalette(
          background: Color(0xFFE7F5FF),
          border: Color(0xFF9BD1FF),
          textColor: Color(0xFF0B4F84),
          icon: Icons.info_outline,
        );
      case WarningBannerType.warning:
        return const _BannerPalette(
          background: Color(0xFFFFF7E8),
          border: Color(0xFFF5CF8B),
          textColor: AppColors.warning,
          icon: Icons.warning_amber_rounded,
        );
      case WarningBannerType.danger:
        return const _BannerPalette(
          background: Color(0xFFFFEBED),
          border: Color(0xFFF4AAB0),
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
