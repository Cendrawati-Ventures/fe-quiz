import 'package:flutter/material.dart';

import '../../app/theme/spacing.dart';
import 'app_button.dart';

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.primaryAction,
    this.secondaryAction,
    this.sticky = true,
  });

  final Widget primaryAction;
  final Widget? secondaryAction;
  final bool sticky;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final content = Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant,
          ),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          if (secondaryAction != null) ...<Widget>[
            Expanded(child: secondaryAction!),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(child: primaryAction),
        ],
      ),
    );

    if (!sticky) {
      return content;
    }
    return SafeArea(top: false, child: content);
  }
}

class BottomActionBarButton extends StatelessWidget {
  const BottomActionBarButton({
    super.key,
    required this.label,
    required this.onPressed,
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
    return AppButton(
      label: label,
      onPressed: onPressed,
      loading: loading,
      disabled: disabled,
      variant: variant,
    );
  }
}
