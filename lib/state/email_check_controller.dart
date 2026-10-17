import 'package:flutter/foundation.dart';

import '../models/breach.dart';
import '../models/email_check_result.dart';
import '../services/breach_api_service.dart';

/// Whether the extra breach details have been requested yet.
sealed class DetailsState {
  const DetailsState();
}

final class DetailsIdle extends DetailsState {
  const DetailsIdle();
}

final class DetailsLoading extends DetailsState {
  const DetailsLoading();
}

final class DetailsLoaded extends DetailsState {
  const DetailsLoaded(this.breaches);
  final List<Breach> breaches;
}

final class DetailsFailed extends DetailsState {
  const DetailsFailed(this.failure);
  final BreachApiFailure failure;
}

/// Everything the results area can be showing.
///
/// The screen is a pure function of this value: one value in, one picture out.
/// That is why the controller only ever replaces it with a new value.
sealed class LookupState {
  const LookupState();
}

final class LookupIdle extends LookupState {
  const LookupIdle();
}

final class LookupLoading extends LookupState {
  const LookupLoading(this.email);
  final String email;
}

final class LookupBreached extends LookupState {
  const LookupBreached(this.email, this.breachNames, {this.details = const DetailsIdle()});

  final String email;
  final List<String> breachNames;
  final DetailsState details;

  LookupBreached withDetails(DetailsState details) =>
      LookupBreached(email, breachNames, details: details);
}

final class LookupClean extends LookupState {
  const LookupClean(this.email);
  final String email;
}

final class LookupFailed extends LookupState {
  const LookupFailed(this.email, this.failure);
  final String email;
  final BreachApiFailure failure;
}

/// Runs lookups and exposes their progress to the UI.
///
/// A [ChangeNotifier] keeps a list of listeners and calls them whenever
/// [notifyListeners] runs. Widgets wrapped in a `ListenableBuilder` rebuild at
/// that moment, which is the whole "state management" story here: no extra
/// package, just "change the value, then notify".
class EmailCheckController extends ChangeNotifier {
  EmailCheckController(this._service);

  final BreachApiService _service;

  LookupState _state = const LookupIdle();
  LookupState get state => _state;

  bool get isLoading => _state is LookupLoading;

  /// Bumped by every new search and by [reset]. A response that arrives for an
  /// older number is stale (the user moved on), so it is thrown away.
  int _generation = 0;
  bool _disposed = false;

  Future<void> check(String email) async {
    if (isLoading) return;

    final generation = ++_generation;
    _set(LookupLoading(email));

    try {
      final result = await _service.checkEmail(email);
      if (generation != _generation) return;

      _set(switch (result) {
        EmailBreached(:final email, :final breachNames) => LookupBreached(email, breachNames),
        EmailClean(:final email) => LookupClean(email),
      });
    } on BreachApiException catch (error) {
      if (generation != _generation) return;
      _set(LookupFailed(email, error.failure));
    } catch (_) {
      // Defensive: whatever went wrong, never leave the screen stuck loading.
      if (generation != _generation) return;
      _set(LookupFailed(email, BreachApiFailure.unexpectedResponse));
    }
  }

  /// The breach details fetched for the address on screen, or an empty list
  /// when there aren't any (no check yet, still loading, clean, or reset).
  List<Breach> get loadedBreaches {
    final current = _state;
    if (current is! LookupBreached) return const [];

    final details = current.details;
    if (details is! DetailsLoaded) return const [];
    return details.breaches;
  }

  /// Bumped each time something asks the form to forget the typed address, for
  /// example "Shake to hide". The email field listens to it and clears itself.
  final ValueNotifier<int> inputWipes = ValueNotifier<int>(0);

  /// Clears the results and asks the form to clear the typed address too.
  void wipe() {
    reset();
    inputWipes.value++;
  }

  /// Fetches the per-breach details for the address currently shown.
  Future<void> loadDetails() async {
    final current = _state;
    if (current is! LookupBreached) return;
    if (current.details is DetailsLoading || current.details is DetailsLoaded) return;

    final generation = _generation;
    _set(current.withDetails(const DetailsLoading()));

    DetailsState outcome;
    try {
      outcome = DetailsLoaded(await _service.fetchBreachDetails(current.email));
    } on BreachApiException catch (error) {
      outcome = DetailsFailed(error.failure);
    } catch (_) {
      outcome = const DetailsFailed(BreachApiFailure.unexpectedResponse);
    }

    // Only apply the outcome if we're still looking at the same search.
    final now = _state;
    if (generation != _generation || now is! LookupBreached) return;
    _set(now.withDetails(outcome));
  }

  /// Clears the results, and ignores any request still in flight.
  void reset() {
    _generation++;
    _set(const LookupIdle());
  }

  void _set(LookupState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    inputWipes.dispose();
    super.dispose();
  }
}
