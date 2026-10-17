import 'package:url_launcher/url_launcher.dart';

/// Opens a web link outside the app.
///
/// An interface so tests can check which link would open without launching a
/// browser.
abstract interface class LinkOpener {
  /// True if the link was handed to the system.
  Future<bool> open(Uri uri);
}

class UrlLauncherLinkOpener implements LinkOpener {
  const UrlLauncherLinkOpener();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

/// Opens nothing. The default in tests.
class NoLinkOpener implements LinkOpener {
  const NoLinkOpener();

  @override
  Future<bool> open(Uri uri) async => false;
}
