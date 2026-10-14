/// The outcome of asking XposedOrNot about one email address.
///
/// It is a sealed class: the compiler knows every possible subtype, so a
/// `switch` over it must handle each one, and adding a new case later makes
/// every incomplete switch fail to compile instead of failing silently.
sealed class EmailCheckResult {
  const EmailCheckResult(this.email);

  /// The address that was checked, trimmed.
  final String email;
}

/// The address appears in at least one known breach.
final class EmailBreached extends EmailCheckResult {
  const EmailBreached(super.email, this.breachNames);

  /// Names of the breaches, in the order the API listed them, without repeats.
  final List<String> breachNames;
}

/// XposedOrNot has no record of the address. This is not proof it is safe,
/// only that it isn't in the breaches XposedOrNot tracks.
final class EmailClean extends EmailCheckResult {
  const EmailClean(super.email);
}
