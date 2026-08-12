import 'package:flutter/material.dart';

/// Barra horizontal sencilla para comparar un valor frente a un máximo de referencia.
class SimpleBar extends StatelessWidget {
  const SimpleBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    this.color,
  });

  final String label;
  final int value;
  final int max;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final denom = max <= 0 ? 1 : max;
    final frac = (value / denom).clamp(0.0, 1.0);
    final barColor = color ?? scheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            Text('$value', style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 10,
            backgroundColor: scheme.surfaceContainerHighest,
            color: barColor,
          ),
        ),
      ],
    );
  }
}
