import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/lottie_assets.dart';
import '../models/remediation.dart';
import '../models/watch_entry.dart';
import '../services/breach_api_service.dart';
import '../state/watchlist_controller.dart';
import '../utils/email_validator.dart';
import '../utils/failure_text.dart';
import '../utils/time_ago.dart';
import '../widgets/exposr_lottie.dart';
import '../widgets/pill.dart';
import '../widgets/screen_header.dart';

/// The Watchlist tab: addresses the user has chosen to keep checking.
///
/// Each address shows when it was last checked, any breaches that appeared
/// since, and a checklist of what to do about them.
class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key, required this.watchlist, this.clock});

  final WatchlistController watchlist;

  /// Where "5 min ago" gets the time from. Defaults to the real clock; tests
  /// pass a fixed one.
  final DateTime Function()? clock;

  static const double _maxContentWidth = 560;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 20.0;

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ScreenHeader(
                    title: 'Watchlist',
                    subtitle: 'Keep an eye on the addresses that matter, and see what changes.',
                  ),
                  const SizedBox(height: 24),
                  _AddAddressCard(watchlist: watchlist),
                  const SizedBox(height: 16),
                  ListenableBuilder(
                    listenable: watchlist,
                    builder: (context, _) => _list(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _list(BuildContext context) {
    final entries = watchlist.entries;
    final textTheme = Theme.of(context).textTheme;

    if (entries.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Center(child: ExposrLottie(asset: LottieAssets.shield, size: 120)),
          const SizedBox(height: 8),
          Text('Nothing on your watchlist', textAlign: TextAlign.center, style: textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Add an address above. Exposr checks it straight away, remembers what it finds, '
            'and flags any breach that turns up later.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      );
    }

    final now = (clock ?? DateTime.now)();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${entries.length} of ${WatchlistController.maxEntries} addresses',
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            OutlinedButton.icon(
              onPressed: watchlist.isBusy ? null : watchlist.checkAll,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(watchlist.isBusy ? 'Checking…' : 'Check all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final entry in entries) ...[
          _EntryCard(
            entry: entry,
            now: now,
            isChecking: watchlist.isChecking(entry.email),
            failure: watchlist.failureFor(entry.email),
            onCheck: () => watchlist.check(entry.email),
            onRemove: () => watchlist.remove(entry.email),
            onAcknowledge: () => watchlist.acknowledge(entry.email),
            onToggleTask: (id) => watchlist.toggleTask(entry.email, id),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        Text(
          'Checking a lot at once can hit XposedOrNot’s free limit of about 25 checks an hour.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: AppColors.textHint),
        ),
      ],
    );
  }
}

/// The "add an address" form.
class _AddAddressCard extends StatefulWidget {
  const _AddAddressCard({required this.watchlist});

  final WatchlistController watchlist;

  @override
  State<_AddAddressCard> createState() => _AddAddressCardState();
}

class _AddAddressCardState extends State<_AddAddressCard> {
  final _formKey = GlobalKey<FormState>();
  final _text = TextEditingController();
  String? _message;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final outcome = await widget.watchlist.add(_text.text);
    if (!mounted) return;

    switch (outcome) {
      case AddOutcome.added:
        _text.clear();
        setState(() => _message = null);
      case AddOutcome.duplicate:
        setState(() => _message = 'That address is already on your watchlist.');
      case AddOutcome.full:
        setState(() => _message = 'The watchlist holds up to ${WatchlistController.maxEntries} addresses. Remove one first.');
      case AddOutcome.invalid:
        setState(() => _message = 'Enter a valid email address.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final message = _message;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _text,
                validator: EmailValidator.validate,
                onFieldSubmitted: (_) => _add(),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Address to watch',
                  hintText: 'name@example.com',
                  prefixIcon: Icon(Icons.visibility_outlined),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message, style: textTheme.bodySmall?.copyWith(color: AppColors.warning)),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: _add, child: const Text('Add to watchlist')),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Watched addresses are saved on this device only, and each check sends the '
                      'address to XposedOrNot over HTTPS. Only add addresses you own or have '
                      'permission to check.',
                      style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One watched address: status, new breaches, checklist and actions.
class _EntryCard extends StatelessWidget {
  const _EntryCard({
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.email,
                    style: textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(entry: entry),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isChecking
                  ? 'Checking…'
                  : checked == null
                      ? 'Not checked yet'
                      : 'Checked ${timeAgo(checked, now)}',
              style: muted,
            ),
            if (problem != null) ...[
              const SizedBox(height: 8),
              Text(
                '${failureTitle(problem)}. ${failureMessage(problem)}',
                style: textTheme.bodySmall?.copyWith(color: AppColors.warning),
              ),
            ],
            if (entry.newBreaches.isNotEmpty) ...[
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New since the last check: ${entry.newBreaches.join(', ')}',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      TextButton(onPressed: onAcknowledge, child: const Text('Got it')),
                    ],
                  ),
                ),
              ),
            ],
            if (entry.knownBreaches.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final name in entry.knownBreaches) Pill(name)],
              ),
              Theme(
                // Removes the divider lines ExpansionTile draws by default.
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(
                    'What to do ($doneCount of ${tasks.length} done)',
                    style: textTheme.titleSmall,
                  ),
                  children: [
                    for (final task in tasks)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        value: entry.completedTasks.contains(task.id),
                        onChanged: (_) => onToggleTask(task.id),
                        title: Text(task.title, style: textTheme.bodyMedium),
                        subtitle: Text(task.detail, style: muted),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
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
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The small status badge: an icon and words, never colour alone.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.entry});

  final WatchEntry entry;

  @override
  Widget build(BuildContext context) {
    final String text;
    final IconData icon;
    final Color color;

    if (entry.newBreaches.isNotEmpty) {
      text = '${entry.newBreaches.length} new';
      icon = Icons.notification_important_outlined;
      color = AppColors.error;
    } else {
      switch (entry.status) {
        case WatchStatus.notChecked:
          text = 'Not checked';
          icon = Icons.schedule;
          color = AppColors.textSecondary;
        case WatchStatus.clear:
          text = 'No breaches';
          icon = Icons.check_circle_outline;
          color = AppColors.success;
        case WatchStatus.breached:
          final count = entry.knownBreaches.length;
          text = '$count ${count == 1 ? 'breach' : 'breaches'}';
          icon = Icons.warning_amber_rounded;
          color = AppColors.warning;
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
