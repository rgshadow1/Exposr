import 'package:local_auth/local_auth.dart';

/// Asks the phone to confirm the person holding it is the owner: fingerprint,
/// face, or the device PIN as a fallback.
///
/// The phone's secure hardware does the checking. This app only ever learns
/// "yes" or "no", never the biometric data itself, and no account is involved.
abstract interface class AppLockService {
  /// Whether this device has any screen lock or biometrics set up.
  Future<bool> isAvailable();

  /// Shows the system prompt. True only if the person passed it.
  Future<bool> authenticate(String reason);
}

class LocalAuthLockService implements AppLockService {
  LocalAuthLockService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason);
    } catch (_) {
      // Cancelled, locked out, or not available: all mean "not unlocked".
      return false;
    }
  }
}

/// A device with no lock: nothing can be authenticated. The default in tests.
class NoAppLockService implements AppLockService {
  const NoAppLockService();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}
