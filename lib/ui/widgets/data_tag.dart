import 'package:flutter/material.dart';

import '../../theme/status_colors.dart';

/// A small outlined label, e.g. a data type ("Passwords") or a flag
/// ("Unverified"). Pass a [tone] to colour it; otherwise it's neutral.
class DataTag extends StatelessWidget {
  const DataTag(this.label, {super.key, this.tone});

  final String label;
  final StatusTone? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone?.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: tone?.border ?? scheme.outlineVariant),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: tone?.foreground ?? scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
