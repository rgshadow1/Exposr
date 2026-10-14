import '../models/breach.dart';

/// The contract between the app and wherever breach data comes from.
///
/// The controller depends on this interface, not on a concrete class. That
/// lets tests pass in a fake implementation, and lets a different data source
/// (another API, a cached copy) be swapped in without touching the UI.
///
/// `abstract interface class` means other classes can implement it but not
/// extend it: it's a pure contract with no shared behaviour.
abstract interface class BreachRepository {
  /// Returns the breaches [email] appears in, newest first.
  ///
  /// Returns an empty list when the address isn't found in any breach.
  /// Throws a `BreachCheckException` for every kind of failure, so callers
  /// only need to handle one exception type.
  Future<List<Breach>> findBreaches(String email);
}
