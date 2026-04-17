import 'package:flutter/material.dart';

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
    final icon = multiSelect
        ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
        : (selected
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(child: Text(option)),
            ],
          ),
        ),
      ),
    );
  }
}
