import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/breach.dart';
import '../services/breach_api_service.dart';
import '../state/email_check_controller.dart';
import 'breach_tile.dart';
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
          // While loading, the button shows the spinner; nothing else to add.
          LookupIdle() || LookupLoading() => const SizedBox(width: double.infinity),
          final LookupBreached breached => _BreachedPanel(
              state: breached,
              onShowDetails: controller.loadDetails,
            ),
          LookupClean(:final email) => StatusPanel(
              tone: AppColors.success,
              icon: Icons.check_circle_outline,
              title: 'No breaches found',
              message: 'XposedOrNot has no record of $email in the breaches it tracks. '
                  'Hey! That is great news, but not a guarantee. '
                  'A breach that has not been reported or added yet would not show up here, keep that in mind!',
            ),
          LookupFailed(:final email, :final failure) => StatusPanel(
              tone: AppColors.warning,
              icon: Icons.error_outline,
              title: _failureTitle(failure),
              message: _failureMessage(failure),
              children: [
                // Retry with the same address.
                OutlinedButton(
                  onPressed: () => controller.check(email),
                  child: const Text('Try again'),
                ),
              ],
            ),
        };

        final hasResult = state is! LookupIdle && state is! LookupLoading;

        // AnimatedSize smoothly grows or shrinks the area as results change.
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: hasResult ? 16 : 0),
            child: content,
          ),
        );
      },
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
            'Details use one more request from the free hourly limit.',
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
          Text(_failureMessage(failure), style: muted),
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

String _failureTitle(BreachApiFailure failure) {
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

String _failureMessage(BreachApiFailure failure) {
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
