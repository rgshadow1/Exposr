import 'package:flutter/material.dart';

import '../../models/breach.dart';
import '../../theme/status_colors.dart';
import 'breach_card.dart';
import 'status_banner.dart';

/// Result state when the address appears in at least one breach.
class BreachesFoundView extends StatelessWidget {
  const BreachesFoundView({
    super.key,
    required this.email,
    required this.breaches,
    required this.onNewSearch,
  });

  final String email;
  final List<Breach> breaches;
  final VoidCallback onNewSearch;

  @override
  Widget build(BuildContext context) {
    final count = breaches.length;
    final noun = count == 1 ? 'breach' : 'breaches';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatusBanner(
          tone: context.statusColors.danger,
          icon: Icons.report_outlined,
          title: 'Found in $count $noun',
          message: '$email appears in the $noun listed below. Change the password '
              'for each service, and anywhere else you used the same password. '
              'Turn on two-factor authentication where it’s available.',
          actions: [
            OutlinedButton(onPressed: onNewSearch, child: const Text('New search')),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Most recent first',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        // A Column rather than a ListView: the whole screen already scrolls,
        // and the list is short (rarely more than a few dozen items).
        for (final breach in breaches) ...[
          BreachCard(breach: breach),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
