import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_tokens.dart';
import '../models/breach.dart';
import '../models/remediation.dart';
import '../services/link_opener.dart';
import '../state/email_check_controller.dart';
import '../utils/failure_text.dart';
import 'breach_list.dart';
import 'check_mark.dart';
import 'inline_progress.dart';
import 'panel.dart';

/// The detail that goes with a finished check, drawn under the check panel.
///
/// The verdict itself (the heading, the count, the address, the animation)
/// lives in the panel. This is what you do with it:
///
///  * breaches found: the breaches, then what to do about them;
///  * none found: a plain statement of what that does and doesn't mean, then
///    habits worth keeping;
///  * failed: what went wrong. There is no result to show, and nothing here
///    could be taken for one.
///
/// `ListenableBuilder` rebuilds only this subtree each time the controller
/// calls `notifyListeners()`, so the rest of the screen is left alone.
class CheckResults extends StatelessWidget {
  const CheckResults({super.key, required this.controller, required this.links});

  final EmailCheckController controller;
  final LinkOpener links;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;

        // switch over a sealed class: the compiler checks every case is here.
        final Widget content = switch (state) {
          LookupIdle() || LookupLoading() => const SizedBox(width: double.infinity),
          final LookupBreached breached => _BreachedDetail(
              state: breached,
              links: links,
              onLoadDetails: controller.loadDetails,
            ),
          LookupClean() => const _CleanDetail(),
          LookupFailed(:final failure) => _FailedDetail(
              icon: failureIcon(failure),
              message: failureMessage(failure),
            ),
        };

        // A short fade between outcomes: no sliding, flashing or shaking, and
        // none at all when the system asks for reduced motion. Keyed by the
        // kind of state, so loading the details of a result already on screen
        // doesn't replay it.
        return AnimatedSwitcher(
          duration: AppMotion.of(context),
          switchInCurve: AppMotion.curve,
          switchOutCurve: AppMotion.curve,
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.passthrough,
            alignment: Alignment.topCenter,
            children: [...previous, if (current != null) current],
          ),
          child: KeyedSubtree(
            key: ValueKey(state is LookupLoading ? LookupIdle : state.runtimeType),
            child: content,
          ),
        );
      },
    );
  }
}

/// A short sentence with a small icon, for a caveat that belongs with a result.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ExcludeSemantics(child: Icon(icon, size: 16, color: AppColors.textMuted)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The icon for each recommended action.
IconData _iconForTask(RemediationTask task) {
  return switch (task.id) {
    'change-passwords' => Icons.key_outlined,
    'unique-passwords' => Icons.password,
    'two-factor' => Icons.phonelink_lock_outlined,
    'phishing' => Icons.mark_email_unread_outlined,
    _ => Icons.check_circle_outline,
  };
}

/// What to do, as a short list of rows: an icon, what to do, and a line on why.
class _Actions extends StatelessWidget {
  const _Actions({required this.title, required this.tasks});

  final String title;
  final List<RemediationTask> tasks;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(title),
        const SizedBox(height: AppSpacing.md),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
          child: Column(
            children: [
              for (var i = 0; i < tasks.length; i++) ...[
                if (i > 0) const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: MergeSemantics(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: ExcludeSemantics(
                            child: Icon(_iconForTask(tasks[i]), size: 20, color: AppColors.accent),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tasks[i].title,
                                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tasks[i].detail,
                                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BreachedDetail extends StatelessWidget {
  const _BreachedDetail({
    required this.state,
    required this.links,
    required this.onLoadDetails,
  });

  final LookupBreached state;
  final LinkOpener links;
  final VoidCallback onLoadDetails;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Note(
          icon: Icons.info_outline,
          text: 'Appearing here means details linked to this address were exposed when those '
              'services were breached. On its own, it doesn’t mean anyone is using your accounts.',
        ),
        const SizedBox(height: AppSpacing.xl),
        _BreachSection(state: state, links: links, onLoadDetails: onLoadDetails),
        const SizedBox(height: AppSpacing.xxl),
        const _Actions(
          title: 'Recommended actions',
          tasks: [changeAffectedPasswordsTask, ...generalRemediationTasks],
        ),
      ],
    );
  }
}

/// The breaches an address was found in: names at first, full rows once the
/// details have been asked for.
class _BreachSection extends StatelessWidget {
  const _BreachSection({required this.state, required this.links, required this.onLoadDetails});

  final LookupBreached state;
  final LinkOpener links;
  final VoidCallback onLoadDetails;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);
    final details = state.details;

    // Once details are in, full rows replace the plain names. (Checking the
    // type inside this expression is what lets Dart treat `details` as a
    // DetailsLoaded for the `.breaches` access.)
    final List<Breach> loaded = details is DetailsLoaded ? details.breaches : const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('Breaches (${state.breachNames.length})'),
        const SizedBox(height: AppSpacing.md),
        if (loaded.isEmpty)
          BreachNameList(names: state.breachNames)
        else ...[
          BreachDetailList(breaches: loaded, links: links),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Newest first. The year is when each breach happened, as reported by '
            'XposedOrNot. It doesn’t say when a breach was disclosed.',
            style: muted,
          ),
        ],
        ..._detailsFooter(context, details),
      ],
    );
  }

  /// The "Load breach details" button, a spinner, or a message under the list.
  List<Widget> _detailsFooter(BuildContext context, DetailsState details) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);
    const gap = SizedBox(height: AppSpacing.lg);

    switch (details) {
      case DetailsIdle():
        return [
          gap,
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: onLoadDetails,
              child: const Text('Load breach details'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Adds the year, size and kinds of data for each breach, and fills in the '
            'Insights tab. It uses one more request from XposedOrNot’s free hourly limit.',
            style: muted,
          ),
        ];
      case DetailsLoading():
        return const [gap, InlineProgress('Loading details…')];
      case DetailsLoaded(:final breaches):
        if (breaches.isNotEmpty) return const [];
        return [
          gap,
          Text('XposedOrNot has no extra details for these breaches.', style: muted),
        ];
      case DetailsFailed(:final failure):
        return [
          gap,
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(
                  child: Icon(Icons.error_outline, size: 18, color: AppColors.warning),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'The details didn’t load. ${failureMessage(failure)}',
                    style: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(onPressed: onLoadDetails, child: const Text('Try again')),
          ),
        ];
    }
  }
}

class _CleanDetail extends StatelessWidget {
  const _CleanDetail();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Note(
          icon: Icons.info_outline,
          text: 'That is good news, but not a guarantee. A breach that hasn’t been discovered, '
              'made public or added to XposedOrNot yet would not show up here.',
        ),
        SizedBox(height: AppSpacing.xl),
        _Actions(title: 'Still worth doing', tasks: generalRemediationTasks),
      ],
    );
  }
}

/// A check that did not complete. It is deliberately nothing like a result: it
/// says why there isn't one. The way to try again is the panel's button.
class _FailedDetail extends StatelessWidget {
  const _FailedDetail({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Panel(
        tone: AppColors.warning,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 20, color: AppColors.warning)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
