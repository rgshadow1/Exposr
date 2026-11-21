import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_tokens.dart';
import '../core/lottie_assets.dart';
import '../services/breach_api_service.dart';
import '../state/email_check_controller.dart';
import 'exposr_lottie.dart';

/// The one mark at the top of the check panel. It always occupies the same
/// square, and its picture follows what the check is doing:
///
///  * **idle**: the radar sweep, for a couple of turns, then at rest;
///  * **checking**: the same sweep, looping and a little faster;
///  * **breaches found**: the alert shield, once;
///  * **no known breaches**: the green ring and check, once;
///  * **failed**: a still icon. A check that didn't finish has no result, so it
///    gets no animation that could be mistaken for one.
///
/// The mark only ever repeats what the words beside it say. It carries no
/// meaning of its own, so it is hidden from screen readers.
class CheckMark extends StatelessWidget {
  const CheckMark({super.key, required this.state, required this.size});

  final LookupState state;
  final double size;

  /// The artwork has a margin; drawing it this much larger fills the slot.
  /// The shield files fill less of their canvas than the success ring, so
  /// the ring is drawn smaller to match their visual weight.
  static const double _overscan = 1.45;
  static const double _ringOverscan = 1.2;

  @override
  Widget build(BuildContext context) {
    final (kind, mark) = _markFor(state);

    // Fades between pictures, and not at all when motion is reduced. The idle
    // and checking marks share a key, so going from one to the other keeps the
    // same animation running and only changes how it plays.
    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.quick),
      switchInCurve: AppMotion.curve,
      switchOutCurve: AppMotion.curve,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: [...previous, if (current != null) current],
      ),
      child: KeyedSubtree(key: ValueKey(kind), child: mark),
    );
  }

  (String, Widget) _markFor(LookupState state) {
    return switch (state) {
      LookupIdle() => (
          'scan',
          ExposrLottie(
            asset: LottieAssets.scan,
            size: size,
            overscan: _overscan,
            // Restrained: two slow sweeps to say "ready", then still.
            repeat: 2,
            speed: 0.7,
            restAt: 0,
            fallback: accentStaticMark(Icons.radar, size),
          ),
        ),
      LookupLoading() => (
          'scan',
          ExposrLottie(
            asset: LottieAssets.scan,
            size: size,
            overscan: _overscan,
            loop: true,
            speed: 1.3,
            restAt: 0,
            fallback: accentStaticMark(Icons.radar, size),
          ),
        ),
      LookupBreached() => (
          'alert',
          ExposrLottie(
            asset: LottieAssets.alert,
            size: size,
            overscan: _overscan,
            fallback: StaticMark(
              icon: Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: size,
            ),
          ),
        ),
      LookupClean() => (
          'success',
          ExposrLottie(
            asset: LottieAssets.success,
            size: size,
            overscan: _ringOverscan,
            fallback: StaticMark(
              icon: Icons.check_circle_outline,
              color: AppColors.success,
              size: size,
            ),
          ),
        ),
      LookupFailed(:final failure) => (
          'failed',
          StaticMark(icon: failureIcon(failure), color: AppColors.warning, size: size),
        ),
    };
  }
}

/// An icon for each way a request can fail.
IconData failureIcon(BreachApiFailure failure) {
  return switch (failure) {
    BreachApiFailure.noConnection => Icons.wifi_off,
    BreachApiFailure.timeout => Icons.timer_off_outlined,
    BreachApiFailure.rateLimited => Icons.hourglass_empty,
    BreachApiFailure.serverError => Icons.cloud_off_outlined,
    BreachApiFailure.unexpectedResponse => Icons.error_outline,
  };
}
