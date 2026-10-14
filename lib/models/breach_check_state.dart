import '../data/breach_check_exception.dart';
import 'breach.dart';

/// Every state the check screen can be in.
///
/// `sealed` means all subclasses must live in this file, so the compiler knows
/// the complete list. A `switch` over a [BreachCheckState] that forgets one
/// case is a compile error, which is exactly what we want for UI states.
sealed class BreachCheckState {
  const BreachCheckState();
}

/// Nothing has been checked yet (or the user started a new search).
final class CheckIdle extends BreachCheckState {
  const CheckIdle();
}

/// A request is in flight.
final class CheckLoading extends BreachCheckState {
  const CheckLoading(this.email);
  final String email;
}

/// The address appears in one or more breaches.
final class CheckBreachesFound extends BreachCheckState {
  const CheckBreachesFound(this.email, this.breaches);
  final String email;
  final List<Breach> breaches;
}

/// HIBP has no record of the address in any breach it returns publicly.
final class CheckNoBreaches extends BreachCheckState {
  const CheckNoBreaches(this.email);
  final String email;
}

/// The check could not be completed.
final class CheckFailed extends BreachCheckState {
  const CheckFailed(this.email, this.error);
  final String email;
  final BreachCheckException error;
}
