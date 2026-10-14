import 'package:flutter/material.dart';

import '../../utils/open_link.dart';

/// Credits Have I Been Pwned as the data source.
///
/// This isn't optional decoration: HIBP's breach data is licensed under
/// CC BY 4.0, which requires visible attribution with a link wherever the
/// data is shown.
class AttributionFooter extends StatelessWidget {
  const AttributionFooter({super.key});

  static final Uri _hibpUrl = Uri.parse('https://haveibeenpwned.com/');
  static final Uri _licenseUrl = Uri.parse('https://creativecommons.org/licenses/by/4.0/');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      minimumSize: const Size(0, 36),
      textStyle: theme.textTheme.bodySmall,
    );

    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Breach data from', style: theme.textTheme.bodySmall),
            TextButton(
              style: linkStyle,
              onPressed: () => openExternalLink(context, _hibpUrl),
              child: const Text('Have I Been Pwned'),
            ),
            Text('under', style: theme.textTheme.bodySmall),
            TextButton(
              style: linkStyle,
              onPressed: () => openExternalLink(context, _licenseUrl),
              child: const Text('CC BY 4.0'),
            ),
          ],
        ),
      ],
    );
  }
}
