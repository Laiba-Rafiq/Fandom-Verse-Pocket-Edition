import 'package:flutter/material.dart';

class ChipSelector extends StatelessWidget {
  const ChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          FilterChip(
            label: Text(option),
            selected: selected.contains(option),
            onSelected: !enabled
                ? null
                : (isSelected) {
                    final updated = List<String>.from(selected);
                    if (isSelected) {
                      updated.add(option);
                    } else {
                      updated.remove(option);
                    }
                    onChanged(updated);
                  },
          ),
      ],
    );
  }
}
