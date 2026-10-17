import 'package:flutter/material.dart';

import '../screens/lock_screen.dart';
import '../services/app_lock_service.dart';
import '../state/settings_controller.dart';

/// Covers the app with the lock screen when the app lock is on and the person
/// hasn't passed the prompt yet.
///
/// The app underneath stays alive but hidden (what you typed isn't lost); it
/// just can't be seen or reached by touch or screen reader until unlocked. The
/// gate locks again whenever the app goes to the background.
class LockGate extends StatefulWidget {
  const LockGate({
    super.key,
    required this.settings,
    required this.lock,
    required this.child,
  });

  final SettingsController settings;
  final AppLockService lock;
  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  late bool _unlocked = !widget.settings.lockEnabled;
  bool _wasEnabled = false;
  bool _authenticating = false;
  bool _lastAttemptFailed = false;

  @override
  void initState() {
    super.initState();
    _wasEnabled = widget.settings.lockEnabled;
    widget.settings.addListener(_onSettingsChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    final enabled = widget.settings.lockEnabled;
    // The lock was only just turned on, and turning it on needs a successful
    // prompt, so the person is by definition already unlocked.
    if (enabled && !_wasEnabled) _unlocked = true;
    _wasEnabled = enabled;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `paused` means the app left the screen. (The system prompt itself only
    // makes the app `inactive`, so showing it doesn't re-lock the app.)
    if (state == AppLifecycleState.paused && widget.settings.lockEnabled && !_authenticating) {
      setState(() => _unlocked = false);
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || _unlocked) return;
    _authenticating = true;

    // If the phone no longer has any screen lock, the prompt can never
    // succeed. Switch the lock off rather than trap the person outside.
    if (!await widget.lock.isAvailable()) {
      _authenticating = false;
      if (!mounted) return;
      await widget.settings.setLockEnabled(false);
      if (mounted) setState(() => _unlocked = true);
      return;
    }

    final ok = await widget.lock.authenticate('Unlock Exposr');
    _authenticating = false;
    if (!mounted) return;
    setState(() {
      _unlocked = ok;
      _lastAttemptFailed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final locked = widget.settings.lockEnabled && !_unlocked;

        return Stack(
          fit: StackFit.expand,
          children: [
            Visibility(visible: !locked, maintainState: true, child: widget.child),
            if (locked)
              Positioned.fill(
                child: LockScreen(onUnlock: _unlock, failed: _lastAttemptFailed),
              ),
          ],
        );
      },
    );
  }
}
