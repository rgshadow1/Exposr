import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/app_tokens.dart';
import '../models/breach.dart';
import '../services/link_opener.dart';
import '../utils/count_format.dart';
import 'password_risk.dart';
import 'tag.dart';
import 'tappable.dart';

/// A bordered list that shows its first [initialCount] rows and offers the
/// rest behind one button, so a long result doesn't bury what follows it.
class _RevealList extends StatefulWidget {
  const _RevealList({
    required this.itemCount,
    required this.itemBuilder,
    required this.initialCount,
    required this.noun,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int initialCount;

  /// What the rows are, in the plural: "breaches".
  final String noun;

  @override
  State<_RevealList> createState() => _RevealListState();
}

class _RevealListState extends State<_RevealList> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final total = widget.itemCount;
    final canCollapse = total > widget.initialCount;
    final visible = _showAll || !canCollapse ? total : widget.initialCount;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.panelAll,
        border: Border.all(color: AppColors.border),
      ),
      // Clips the rows' hover tint to the rounded corners.
      child: ClipRRect(
        borderRadius: AppRadii.panelAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < visible; i++) ...[
              if (i > 0) const Divider(),
              widget.itemBuilder(context, i),
            ],
            if (canCollapse) ...[
              const Divider(),
              TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                style: TextButton.styleFrom(shape: const RoundedRectangleBorder()),
                child: Text(_showAll ? 'Show fewer' : 'Show all $total ${widget.noun}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Breach names only: what the first, cheap lookup returns.
class BreachNameList extends StatelessWidget {
  const BreachNameList({super.key, required this.names, this.initialCount = 8});

  final List<String> names;
  final int initialCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return _RevealList(
      itemCount: names.length,
      initialCount: initialCount,
      noun: 'breaches',
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Text(
            names[index],
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        );
      },
    );
  }
}

/// The breaches with their details. Each row shows the essentials (name,
/// year, size, kinds of data) and opens to show the rest.
class BreachDetailList extends StatelessWidget {
  const BreachDetailList({
    super.key,
    required this.breaches,
    required this.links,
    this.initialCount = 10,
  });

  final List<Breach> breaches;
  final LinkOpener links;
  final int initialCount;

  @override
  Widget build(BuildContext context) {
    return _RevealList(
      itemCount: breaches.length,
      initialCount: initialCount,
      noun: 'breaches',
      itemBuilder: (context, index) {
        final breach = breaches[index];
        // Keyed by position and name, so a row keeps its open/closed state.
        return BreachDetailRow(key: ValueKey('$index:${breach.name}'), breach: breach, links: links);
      },
    );
  }
}

/// One breach: a header that toggles, its data tags, and the longer details.
class BreachDetailRow extends StatefulWidget {
  const BreachDetailRow({super.key, required this.breach, required this.links});

  final Breach breach;
  final LinkOpener links;

  @override
  State<BreachDetailRow> createState() => _BreachDetailRowState();
}

class _BreachDetailRowState extends State<BreachDetailRow> {
  bool _expanded = false;

  Future<void> _openReference(Uri uri) async {
    // Read the messenger before the `await`: after an async gap this widget
    // may be gone, and its context must not be used then.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final opened = await widget.links.open(uri);
    if (!opened) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Couldn’t open the link.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final breach = widget.breach;
    final muted = textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    // Only the facts we actually have, joined with a middle dot.
    final summary = [
      if (breach.year != null) 'Breached ${breach.year}',
      if (breach.records != null) '${formatCount(breach.records!)} records',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          hint: _expanded ? 'Hides the details' : 'Shows the details',
          child: Tappable(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                14,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          breach.name,
                          maxLines: _expanded ? null : 2,
                          overflow: _expanded ? null : TextOverflow.ellipsis,
                          style: textTheme.titleSmall,
                        ),
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            summary,
                            style: muted?.copyWith(fontFeatures: AppTheme.tabularFigures),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ExcludeSemantics(
                    child: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (breach.exposedData.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 14),
            child: Semantics(
              label: 'Exposed data',
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final kind in breach.exposedData)
                    // Passwords are the item most worth noticing.
                    if (mentionsPasswords(kind))
                      Tag(kind, tone: AppColors.danger, icon: Icons.key_outlined)
                    else
                      Tag(kind),
                ],
              ),
            ),
          ),
        if (_expanded) _details(context),
      ],
    );
  }

  Widget _details(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final breach = widget.breach;
    final description = breach.description;
    final reference = breach.reference;
    final hasPasswords = breach.exposedData.any(mentionsPasswords);
    final showRisk = breach.passwordRisk != PasswordRisk.unknown || hasPasswords;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description != null) ...[
            Text(
              description,
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.55),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Wrap(
            spacing: AppSpacing.xxl,
            runSpacing: AppSpacing.md,
            children: [
              _Fact(label: 'Breach year', value: breach.year?.toString() ?? 'Not stated'),
              if (breach.records != null)
                _Fact(label: 'Records in the breach', value: formatCount(breach.records!)),
              if (showRisk)
                _Fact(
                  label: 'Password storage',
                  value: passwordRiskLabel(breach.passwordRisk),
                  valueColor: passwordRiskColor(breach.passwordRisk),
                ),
              if (breach.domain != null) _Fact(label: 'Domain', value: breach.domain!),
              if (breach.industry != null) _Fact(label: 'Industry', value: breach.industry!),
              if (breach.verified) const _Fact(label: 'Source', value: 'Verified by XposedOrNot'),
            ],
          ),
          if (reference != null) ...[
            const SizedBox(height: AppSpacing.sm),
            // Pulled left so the label lines up with the text above it.
            Transform.translate(
              offset: const Offset(-12, 0),
              child: TextButton.icon(
                onPressed: () => _openReference(reference),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text('Read more at ${reference.host}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small label over its value.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
              fontFeatures: AppTheme.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
