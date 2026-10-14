import 'package:flutter/material.dart';

import '../../theme/status_colors.dart';
import 'status_banner.dart';

/// Result state when HIBP has no record of the address.
///
/// The footnote matters: "not found" only means "not found in the breaches
/// HIBP publicly returns", and the UI shouldn't imply more than that.
class NoBreachesView extends StatelessWidget {
  const NoBreachesView({super.key, required this.email, required this.onNewSearch});

  final String email;
  final VoidCallback onNewSearch;

  @override
  Widget build(BuildContext context) {
    return StatusBanner(
      tone: context.statusColors.success,
      icon: Icons.check_circle_outline,
      title: 'No breaches found',
      message: '$email wasn’t found in any breach that Have I Been Pwned '
          'makes searchable.',
      footnote: 'This isn’t a guarantee. Many breaches are never made public, '
          'and breaches HIBP marks as sensitive aren’t returned by this search.',
      actions: [
        OutlinedButton(onPressed: onNewSearch, child: const Text('New search')),
      ],
    );
  }
}
