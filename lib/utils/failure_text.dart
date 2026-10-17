import '../services/breach_api_service.dart';

/// The wording for each way a request can fail, shared by every screen that
/// shows one, so the same problem is always explained the same way.
String failureTitle(BreachApiFailure failure) {
  switch (failure) {
    case BreachApiFailure.noConnection:
      return 'Couldn’t connect';
    case BreachApiFailure.timeout:
      return 'Request timed out';
    case BreachApiFailure.rateLimited:
      return 'Too many checks';
    case BreachApiFailure.serverError:
      return 'Service unavailable';
    case BreachApiFailure.unexpectedResponse:
      return 'Unexpected response';
  }
}

String failureMessage(BreachApiFailure failure) {
  switch (failure) {
    case BreachApiFailure.noConnection:
      return 'Couldn’t reach XposedOrNot. Check your internet connection and try again.';
    case BreachApiFailure.timeout:
      return 'XposedOrNot took too long to answer. Try again in a moment.';
    case BreachApiFailure.rateLimited:
      return 'XposedOrNot’s free service limits how many checks each network can make '
          'per hour and per day, and that limit has been reached. Wait a while, then try again.';
    case BreachApiFailure.serverError:
      return 'XposedOrNot is having problems right now. Try again later.';
    case BreachApiFailure.unexpectedResponse:
      return 'XposedOrNot sent a reply this app couldn’t understand. Try again later.';
  }
}
