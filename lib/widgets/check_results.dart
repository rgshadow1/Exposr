import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/lottie_assets.dart';
import '../models/breach.dart';
import '../state/email_check_controller.dart';
import '../utils/failure_text.dart';
import 'breach_tile.dart';
import 'exposr_lottie.dart';
import 'pill.dart';
import 'status_panel.dart';

/// Shows whatever the controller's current [LookupState] calls for.
///
/// `ListenableBuilder` rebuilds only this subtree each time the controller
/// calls `notifyListeners()`, so the rest of the screen is left alone.
class CheckResults extends StatelessWidget {
  const CheckResults({super.key, required this.controller});

  final EmailCheckController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;

        // switch over a sealed class: the compiler checks every case is here.
        final Widget content = switch (state) {
          LookupIdle() => const SizedBox(width: double.infinity),
          // While the request runs, a looping radar animation says "working".
          LookupLoading() => const _ScanningPanel(),
          final LookupBreached breached => _BreachedPanel(
              state: breached,
              onShowDetails: controller.loadDetails,
            ),
          LookupClean(:final email) => StatusPanel(
              tone: AppColors.success,
              icon: Icons.check_circle_outline,
              animationAsset: LottieAssets.success,
              title: 'No breaches found',
              message: 'XposedOrNot has no record of $email in the breaches it tracks. '
                  'Hey! That is great news, but not a guarantee. '
                  'A breach that has not been reported or added yet would not show up here, keep that in mind!',
            ),
          LookupFailed(:final email, :final failure) => StatusPanel(
              tone: AppColors.warning,
              icon: Icons.error_outline,
              title: failureTitle(failure),
              message: failureMessage(failure),
              children: [
                // Retry with the same address.
                OutlinedButton(
                  onPressed: () => controller.check(email),
                  child: const Text('Try again'),
                ),
              ],
            ),
        };

        final hasContent = state is! LookupIdle;

        // AnimatedSize smoothly grows or shrinks the area as results change.
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: hasContent ? 16 : 0),
            child: content,
          ),
        );
      },
    );
  }
}

/// Shown while a check is running: a looping radar sweep around a shield.
class _ScanningPanel extends StatelessWidget {
  const _ScanningPanel();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      liveRegion: true,
      label: 'Searching known breaches',
      child: ExcludeSemantics(
        child: Column(
          children: [
            const ExposrLottie(asset: LottieAssets.scan, size: 120, loop: true),
            Text(
              'Searching known breaches…',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreachedPanel extends StatelessWidget {
  const _BreachedPanel({required this.state, required this.onShowDetails});

  final LookupBreached state;
  final VoidCallback onShowDetails;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final count = state.breachNames.length;
    final details = state.details;

    // Once details are in, tiles replace the plain name chips. (Checking the
    // type inside this expression is what lets Dart treat `details` as a
    // DetailsLoaded for the `.breaches` access.)
    final List<Breach> tiles = details is DetailsLoaded ? details.breaches : const [];

    return StatusPanel(
      tone: AppColors.error,
      icon: Icons.warning_amber_rounded,
      animationAsset: LottieAssets.alert,
      title: 'Found in $count ${count == 1 ? 'breach' : 'breaches'}',
      message: '${state.email} appears in known data breaches. Please change the password ASAP for any accounts that used it, '
          'and turn on two-factor '
          'authentication (2FA) where you can.',
      children: [
        if (tiles.isEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final name in state.breachNames) Pill(name)],
          )
        else
          _TileList(breaches: tiles),
        ..._detailsFooter(context, textTheme, details),
      ],
    );
  }

  /// The "Show details" button, spinner or message under the list.
  List<Widget> _detailsFooter(BuildContext context, TextTheme textTheme, DetailsState details) {
    final muted = textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    switch (details) {
      case DetailsIdle():
        return [
          OutlinedButton(onPressed: onShowDetails, child: const Text('Show details')),
          Text(
            'Details use one more request from the free hourly limit. '
            'They also unlock the Insights tab.',
            textAlign: TextAlign.center,
            style: muted,
          ),
        ];
      case DetailsLoading():
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  semanticsLabel: 'Loading details',
                ),
              ),
              const SizedBox(width: 12),
              Text('Loading details…', style: muted),
            ],
          ),
        ];
      case DetailsLoaded(:final breaches):
        if (breaches.isNotEmpty) return const [];
        return [
          Text(
            'XposedOrNot has no extra details for these breaches.',
            textAlign: TextAlign.center,
            style: muted,
          ),
        ];
      case DetailsFailed(:final failure):
        return [
          Text(failureMessage(failure), style: muted),
          OutlinedButton(onPressed: onShowDetails, child: const Text('Try again')),
        ];
    }
  }
}

/// The detailed breaches, one tile each with a gap between.
class _TileList extends StatelessWidget {
  const _TileList({required this.breaches});

  final List<Breach> breaches;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < breaches.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          BreachTile(breach: breaches[i]),
        ],
      ],
    );
  }
}
