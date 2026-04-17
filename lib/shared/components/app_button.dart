import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, danger, ghost }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.loading = false,
    this.disabled = false,
    this.variant = AppButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool disabled;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = _resolveStyle(scheme);
    final progressColor = _progressColor(scheme);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: style,
        onPressed: (loading || disabled) ? null : onPressed,
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              )
            : Text(label),
      ),
    );
  }

  ButtonStyle _resolveStyle(ColorScheme scheme) {
    switch (variant) {
      case AppButtonVariant.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shadowColor: scheme.primary.withValues(alpha: 0.35),
          elevation: 1.5,
          minimumSize: const Size.fromHeight(48),
        );
      case AppButtonVariant.secondary:
        return ElevatedButton.styleFrom(
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
          shadowColor: scheme.secondary.withValues(alpha: 0.2),
          elevation: 1,
          minimumSize: const Size.fromHeight(48),
        );
      case AppButtonVariant.danger:
        return ElevatedButton.styleFrom(
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
          shadowColor: scheme.error.withValues(alpha: 0.25),
          elevation: 1,
          minimumSize: const Size.fromHeight(48),
        );
      case AppButtonVariant.ghost:
        return ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary.withValues(alpha: 0.08),
          foregroundColor: scheme.primary,
          minimumSize: const Size.fromHeight(48),
        );
    }
  }

  Color _progressColor(ColorScheme scheme) {
    switch (variant) {
      case AppButtonVariant.primary:
        return scheme.onPrimary;
      case AppButtonVariant.secondary:
        return scheme.onSecondaryContainer;
      case AppButtonVariant.danger:
        return scheme.onError;
      case AppButtonVariant.ghost:
        return scheme.primary;
    }
  }
}
