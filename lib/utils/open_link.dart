import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the user's browser, showing a short message if that fails
/// (for example, no browser is installed on a test device).
///
/// `externalApplication` sends the link to the real browser rather than an
/// in-app web view, so the user sees the actual address bar.
Future<void> openExternalLink(BuildContext context, Uri url) async {
  // Read the messenger before the `await`: after an async gap the widget may
  // have been removed from the tree, and its context must not be used then.
  final messenger = ScaffoldMessenger.maybeOf(context);

  bool opened;
  try {
    opened = await launchUrl(url, mode: LaunchMode.externalApplication);
  } on Exception {
    // e.g. PlatformException when no app can handle the URL.
    opened = false;
  }

  if (!opened) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Couldn’t open the link.')),
    );
  }
}
