/// Paths of the animation files, in one place.
///
/// These are original animations made for Exposr (see tool/generate_lottie.py).
/// To use a different animation, for example one downloaded from LottieFiles,
/// replace the file at the same path (or change the path here). Nothing else
/// needs to change.
abstract final class LottieAssets {
  /// A radar sweep around a shield. Loops while a check is running.
  static const String scan = 'assets/lottie/scan.json';

  /// A green ring with a check mark that draws itself. Plays once.
  static const String success = 'assets/lottie/success.json';

  /// A red shield with an exclamation mark that shakes and pulses. Plays once.
  static const String alert = 'assets/lottie/alert.json';

  /// The shield-and-eye mark drawing itself. Plays once.
  static const String shield = 'assets/lottie/shield.json';
}
