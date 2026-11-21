import 'package:flutter/services.dart';

/// Loads the Inter font the app ships, so a widget test lays text out with the
/// real glyph widths.
///
/// Without it the test engine draws every glyph as a square of the same width.
/// That is fine for finding widgets, but a test about where lines wrap, or
/// about whether one layout moves another, would be measuring the wrong font.
///
/// Call once from `setUpAll`, after `TestWidgetsFlutterBinding.ensureInitialized()`.
Future<void> loadInter() async {
  final loader = FontLoader('Inter');
  for (final weight in ['400', '500', '600', '700']) {
    loader.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
  }
  await loader.load();
}
