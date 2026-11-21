import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_tokens.dart';
import '../models/remediation.dart';
import '../models/watch_entry.dart';
import '../services/breach_api_service.dart';
import '../state/watchlist_controller.dart';
import '../utils/email_validator.dart';
import '../utils/failure_text.dart';
import '../utils/time_ago.dart';
import '../widgets/app_page.dart';
import '../widgets/panel.dart';
import '../widgets/tag.dart';

/// The Watchlist tab: addresses the user has saved to check again.
///
/// Each address shows when it was last checked, any breaches that appeared
/// since, and a checklist of what to do about them. Nothing here runs in the
/// background: an address is only checked when the user asks.
class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key, required this.watchlist, this.clock});

  final WatchlistController watchlist;

  /// Where "5 min ago" gets the time from. Defaults to the real clock; tests
  /// pass a fixed one.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Watchlist',
      subtitle: 'Addresses you want to check again. Exposr checks them only when you ask, '
          'never in the background.',
      children: [
        _AddAddressForm(watchlist: watchlist),
        const SizedBox(height: AppSpacing.xl),
        ListenableBuilder(
          listenable: watchlist,
          builder: (context, _) => _list(context),
        ),
      ],
    );
  }

  Widget _list(BuildContext context) {
    final entries = watchlist.entries;
    final textTheme = Theme.of(context).textTheme;

    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.visibility_outlined,
        title: 'Nothing on your watchlist',
        message: 'Add an address above. Exposr checks it once straight away and remembers '
            'what it found. When you check it again later, any breach that wasn’t there '
            'before is flagged as new.',
      );
    }

    final now = (clock ?? DateTime.now)();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Wrap, not Row: the count drops under the button when space is short.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: [
            Text(
              '${entries.length} of ${WatchlistController.maxEntries} addresses',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            OutlinedButton.icon(
              onPressed: watchlist.isBusy ? null : watchlist.checkAll,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(watchlist.isBusy ? 'Checking…' : 'Check all'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final entry in entries) ...[
          _EntryPanel(
            entry: entry,
            now: now,
            isChecking: watchlist.isChecking(entry.email),
            failure: watchlist.failureFor(entry.email),
            onCheck: () => watchlist.check(entry.email),
            onRemove: () => watchlist.remove(entry.email),
            onAcknowledge: () => watchlist.acknowledge(entry.email),
            onToggleTask: (id) => watchlist.toggleTask(entry.email, id),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Checking a lot at once can hit XposedOrNot’s free limit of about 25 checks an hour.',
          style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// The "add an address" form.
class _AddAddressForm extends StatefulWidget {
  const _AddAddressForm({required this.watchlist});

  final WatchlistController watchlist;

  @override
  State<_AddAddressForm> createState() => _AddAddressFormState();
}

class _AddAddressFormState extends State<_AddAddressForm> {
  static const String _fieldLabel = 'Address to watch';

  final _formKey = GlobalKey<FormState>();
  final _text = TextEditingController();
  String? _message;
  bool _adding = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    // One add at a time: a second Enter while the first is saving is ignored.
    if (_adding) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    _adding = true;
    final AddOutcome outcome;
    try {
      outcome = await widget.watchlist.add(_text.text);
    } finally {
      _adding = false;
    }
    if (!mounted) return;

    switch (outcome) {
      case AddOutcome.added:
        _text.clear();
        setState(() => _message = null);
      case AddOutcome.duplicate:
        setState(() => _message = 'That address is already on your watchlist.');
      case AddOutcome.full:
        setState(
          () => _message = 'The watchlist holds up to ${WatchlistController.maxEntries} '
              'addresses. Remove one first.',
        );
      case AddOutcome.invalid:
        setState(() => _message = 'Enter a valid email address.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final message = _message;

    final field = Semantics(
      label: _fieldLabel,
      child: TextFormField(
        controller: _text,
        validator: EmailValidator.validate,
        onFieldSubmitted: (_) => _add(),
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.email],
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(hintText: 'you@example.com'),
      ),
    );
    final button = FilledButton(onPressed: _add, child: const Text('Add to watchlist'));

    return Panel(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(child: Text(_fieldLabel, style: textTheme.labelMedium)),
            const SizedBox(height: AppSpacing.sm),
            // Field and button share a row when there is room for both.
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 480) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [field, const SizedBox(height: AppSpacing.md), button],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: AppSpacing.md),
                    button,
                  ],
                );
              },
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(message, style: textTheme.bodySmall?.copyWith(color: AppColors.warning)),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              'The list is kept on this device, in Exposr’s own storage. Each check sends the '
              'address to XposedOrNot over HTTPS, exactly like a check on Home. Only add '
              'addresses you own or have permission to check.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// One watched address: status, new breaches, checklist and actions.
class _EntryPanel extends StatelessWidget {
  const _EntryPanel({
    required this.entry,
    required this.now,
    required this.isChecking,
    required this.failure,
    required this.onCheck,
    required this.onRemove,
    required this.onAcknowledge,
    required this.onToggleTask,
  });

  final WatchEntry entry;
  final DateTime now;
  final bool isChecking;
  final BreachApiFailure? failure;
  final VoidCallback onCheck;
  final VoidCallback onRemove;
  final VoidCallback onAcknowledge;
  final void Function(String taskId) onToggleTask;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);
    final checked = entry.lastChecked;
    final problem = failure;
    final tasks = remediationTasksFor(entry.knownBreaches);
    final doneCount = tasks.where((task) => entry.completedTasks.contains(task.id)).length;

    return Panel(
      padding: const EdgeInsets.fromLTRB(20, AppSpacing.lg, 20, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wrap, not Row: a long address pushes the status onto its own line
          // rather than squeezing it.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              Text(entry.email, style: textTheme.titleSmall),
              _StatusTag(entry: entry),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isChecking
                ? 'Checking…'
                : checked == null
                    ? 'Not checked yet'
                    : 'Checked ${timeAgo(checked, now)}',
            style: muted,
          ),
          if (problem != null) ...[
            const SizedBox(height: AppSpacing.md),
            // A failed check never changes the status above: it only says the
            // latest attempt didn't complete.
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
                      '${failureTitle(problem)}. ${failureMessage(problem)}',
                      style: muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (entry.newBreaches.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Panel(
              tone: AppColors.danger,
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New since the last check: ${entry.newBreaches.join(', ')}',
                    style: textTheme.bodyMedium,
                  ),
                  // Pulled left so the label lines up with the text above.
                  Transform.translate(
                    offset: const Offset(-12, 0),
                    child: TextButton(onPressed: onAcknowledge, child: const Text('Got it')),
                  ),
                ],
              ),
            ),
          ],
          if (entry.knownBreaches.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final name in entry.knownBreaches) Tag(name)],
            ),
            const SizedBox(height: AppSpacing.xs),
            Theme(
              // Removes the divider lines ExpansionTile draws by default.
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                shape: const Border(),
                collapsedShape: const Border(),
                textColor: AppColors.textPrimary,
                collapsedTextColor: AppColors.textPrimary,
                iconColor: AppColors.textMuted,
                collapsedIconColor: AppColors.textMuted,
                title: Text(
                  'What to do ($doneCount of ${tasks.length} done)',
                  style: textTheme.titleSmall,
                ),
                children: [
                  for (final task in tasks)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: entry.completedTasks.contains(task.id),
                      onChanged: (_) => onToggleTask(task.id),
                      title: Text(task.title),
                      subtitle: Text(task.detail),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          // Wrap, so the two actions stack instead of overflowing on a narrow
          // screen or with large text.
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.xs,
            children: [
              TextButton.icon(
                onPressed: isChecking ? null : onCheck,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Check now'),
              ),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove'),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The small status label: an icon and words, never colour alone.
class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.entry});

  final WatchEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.newBreaches.isNotEmpty) {
      return Tag(
        '${entry.newBreaches.length} new',
        tone: AppColors.danger,
        icon: Icons.notification_important_outlined,
      );
    }

    switch (entry.status) {
      case WatchStatus.notChecked:
        return const Tag('Not checked', icon: Icons.schedule);
      case WatchStatus.clear:
        return const Tag(
          'No known breaches',
          tone: AppColors.success,
          icon: Icons.check_circle_outline,
        );
      case WatchStatus.breached:
        final count = entry.knownBreaches.length;
        return Tag(
          '$count ${count == 1 ? 'breach' : 'breaches'}',
          tone: AppColors.warning,
          icon: Icons.warning_amber_rounded,
        );
    }
  }
}
