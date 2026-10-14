import 'package:flutter/foundation.dart';

import '../data/breach_check_exception.dart';
import '../data/breach_repository.dart';
import '../models/breach_check_state.dart';

/// Holds the current [BreachCheckState] and changes it in response to user
/// actions.
///
/// It extends [ChangeNotifier], Flutter's built-in observable: widgets listen
/// to it (via `ListenableBuilder`) and rebuild whenever [notifyListeners] is
/// called. There's no UI code here, which is what makes it easy to unit test.
class BreachCheckController extends ChangeNotifier {
  BreachCheckController(this._repository);

  final BreachRepository _repository;

  BreachCheckState _state = const CheckIdle();
  BreachCheckState get state => _state;

  bool get isLoading => _state is CheckLoading;

  /// Incremented for every new request. If the user starts a new search (or
  /// resets) while an older request is still running, the older result is
  /// ignored when it finally arrives instead of overwriting the newer state.
  int _requestId = 0;

  bool _disposed = false;

  /// Looks up [email]. The caller is expected to have validated it already.
  Future<void> check(String email) async {
    final normalizedEmail = email.trim();
    final requestId = ++_requestId;
    _setState(CheckLoading(normalizedEmail));

    BreachCheckState result;
    try {
      final breaches = await _repository.findBreaches(normalizedEmail);
      result = breaches.isEmpty
          ? CheckNoBreaches(normalizedEmail)
          : CheckBreachesFound(normalizedEmail, List.unmodifiable(breaches));
    } on BreachCheckException catch (error) {
      result = CheckFailed(normalizedEmail, error);
    } catch (error, stackTrace) {
      // The repository should only throw BreachCheckException, so reaching
      // this means a bug. Report it (without the email) and show a generic
      // error rather than leaving the UI stuck on the loading state.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'breach_checker',
          context: ErrorDescription('while checking an email address'),
        ),
      );
      result = CheckFailed(
        normalizedEmail,
        const BreachCheckException(BreachCheckFailure.unexpectedResponse),
      );
    }

    if (requestId == _requestId) _setState(result);
  }

  /// Returns to the idle state for a new search.
  void reset() {
    _requestId++;
    _setState(const CheckIdle());
  }

  void _setState(BreachCheckState newState) {
    if (_disposed) return;
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
