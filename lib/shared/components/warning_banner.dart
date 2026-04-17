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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: _backgroundColor(type),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Color _backgroundColor(WarningBannerType type) {
    switch (type) {
      case WarningBannerType.info:
        return AppColors.info;
      case WarningBannerType.warning:
        return AppColors.warning;
      case WarningBannerType.danger:
        return AppColors.danger;
    }
  }
}
