import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';

class OptionItem extends StatelessWidget {
  const OptionItem({
    super.key,
    required this.option,
    required this.selected,
    required this.multiSelect,
    required this.onTap,
  });

  final String option;
  final bool selected;
  final bool multiSelect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final backgroundColor = selected
        ? scheme.primaryContainer.withValues(alpha: 0.5)
        : Colors.white;
    final borderColor = selected ? scheme.primary : AppColors.borderDefault;
    final iconColor = selected ? scheme.primary : AppColors.textSecondary;

    final icon = multiSelect
        ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
        : (selected
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
