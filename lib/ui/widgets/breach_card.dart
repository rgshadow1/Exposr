import 'package:flutter/material.dart';

import '../../models/breach.dart';
import '../../theme/status_colors.dart';
import '../../utils/formatters.dart';
import '../../utils/open_link.dart';
import 'data_tag.dart';

/// Shows one [Breach]: what service, when, what was exposed, and a link to
/// HIBP's page about it.
class BreachCard extends StatelessWidget {
  const BreachCard({super.key, required this.breach});

  final Breach breach;

  /// Data types that most directly put accounts or money at risk. These are
  /// highlighted so they stand out in a long list of exposed fields.
  static const Set<String> _highRiskDataClasses = {
    'Passwords',
    'Password hints',
    'Security questions and answers',
    'Auth tokens',
    'Credit cards',
    'Credit card CVV',
    'Partial credit card data',
    'Bank account numbers',
    'Government issued IDs',
    'Social security numbers',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = context.statusColors;
    final flags = _flags();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(breach.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(_metadataLine(), style: theme.textTheme.bodySmall),
            if (flags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final flag in flags) DataTag(flag, tone: status.warning)],
              ),
            ],
            if (breach.dataClasses.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Exposed data', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final dataClass in breach.dataClasses)
                    DataTag(
                      dataClass,
                      tone: _highRiskDataClasses.contains(dataClass) ? status.danger : null,
                    ),
                ],
              ),
            ],
            if (breach.description.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ExpandableText(breach.description),
            ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => openExternalLink(context, breach.infoUrl),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('View on Have I Been Pwned'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// e.g. "adobe.com · Breached 4 Oct 2013 · 152,445,165 accounts"
  String _metadataLine() {
    final parts = <String>[
      if (breach.domain != null) breach.domain!,
      if (breach.breachDate != null) 'Breached ${Formatters.date(breach.breachDate!)}',
      if (breach.pwnCount != null) '${Formatters.count(breach.pwnCount!)} accounts',
    ];
    return parts.isEmpty ? 'No further details available' : parts.join(' · ');
  }

  /// Caveats HIBP attaches to a breach. Worth showing, because they change
  /// how much a result should worry you.
  List<String> _flags() => [
        if (!breach.isVerified) 'Unverified',
        if (breach.isFabricated) 'Likely fabricated',
        if (breach.isSpamList) 'Spam list',
        if (breach.isMalware) 'Malware',
        if (breach.isStealerLog) 'Stealer log',
      ];
}

/// Description text that starts collapsed when it's long.
///
/// This is a StatefulWidget because "expanded or not" is state that belongs
/// to this one card and nothing else in the app cares about it.
class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text);

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  static const int _collapsedLines = 4;

  /// Rough cut-off for when a "Show more" toggle is worth showing.
  static const int _longTextLength = 240;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isLong = widget.text.length > _longTextLength;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: Text(
            widget.text,
            style: style,
            maxLines: isLong && !_expanded ? _collapsedLines : null,
            overflow: isLong && !_expanded ? TextOverflow.ellipsis : TextOverflow.visible,
          ),
        ),
        if (isLong)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
            child: Text(_expanded ? 'Show less' : 'Show more'),
          ),
      ],
    );
  }
}
