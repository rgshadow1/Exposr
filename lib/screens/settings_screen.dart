import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_info.dart';
import '../core/app_tokens.dart';
import '../services/app_lock_service.dart';
import '../services/link_opener.dart';
import '../state/email_check_controller.dart';
import '../state/result_feedback.dart';
import '../state/settings_controller.dart';
import '../state/watchlist_controller.dart';
import '../widgets/app_page.dart';
import '../widgets/panel.dart';

/// The Settings tab: feedback and security switches, what the app does with
/// data, and the About sections.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.watchlist,
    required this.lookup,
    required this.feedback,
    required this.lock,
    required this.links,
  });

  final SettingsController settings;
  final WatchlistController watchlist;
  final EmailCheckController lookup;

  /// Used to preview the result feedback, and to know whether this device
  /// can give haptics at all.
  final ResultFeedback feedback;
  final AppLockService lock;
  final LinkOpener links;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Asked once: whether this phone has a screen lock or biometrics at all.
  late final Future<bool> _lockAvailable = widget.lock.isAvailable();

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleLock(bool wanted) async {
    if (!wanted) {
      await widget.settings.setLockEnabled(false);
      return;
    }
    // Turning the lock on means proving it works, so nobody can lock
    // themselves out with a lock that doesn't open.
    final ok = await widget.lock.authenticate('Confirm it’s you to turn on the app lock.');
    if (!mounted) return;
    if (ok) {
      await widget.settings.setLockEnabled(true);
    } else {
      _snack('The app lock wasn’t turned on.');
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This removes your watchlist and resets every setting on this device. It can’t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    widget.lookup.wipe();
    await widget.watchlist.clearAll();
    await widget.settings.resetToDefaults();
    if (!mounted) return;
    _snack('All data cleared.');
  }

  Future<void> _open(Uri uri, String label) async {
    final opened = await widget.links.open(uri);
    if (!opened && mounted) {
      _snack('Couldn’t open the link. You can find it at $label.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);
    final hapticsSupported = widget.feedback.hapticsSupported;
    const gap = SizedBox(height: AppSpacing.xl);

    return AppPage(
      title: 'Settings',
      subtitle: 'Feedback, security and what Exposr does with your data.',
      children: [
        ListenableBuilder(
          listenable: widget.settings,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Section(
                  title: 'Feedback',
                  children: [
                    SwitchListTile(
                      // On a device with no haptics the switch is off and
                      // locked, with the reason underneath.
                      value: hapticsSupported && widget.settings.hapticsEnabled,
                      onChanged: hapticsSupported ? widget.settings.setHapticsEnabled : null,
                      title: const Text('Haptic feedback'),
                      subtitle: Text(
                        hapticsSupported
                            ? 'A brief warning tap when breaches are found and a light confirmation '
                                'when none are. Your device’s own vibration settings still apply.'
                            : 'This device doesn’t support haptic feedback.',
                      ),
                    ),
                    SwitchListTile(
                      value: widget.settings.soundsEnabled,
                      onChanged: widget.settings.setSoundsEnabled,
                      title: const Text('Result sounds'),
                      subtitle: const Text(
                        'Plays result sounds, one positive and one negative.',
                      ),
                    ),
                    _FeedbackPreview(feedback: widget.feedback),
                    SwitchListTile(
                      value: widget.settings.shakeToHideEnabled,
                      onChanged: widget.settings.setShakeToHideEnabled,
                      title: const Text('Shake to hide'),
                      subtitle: const Text(
                        'Shake your phone to clear the address and results from the screen, '
                        'in case someone is looking over your shoulder.',
                      ),
                    ),
                  ],
                ),
                gap,
                _Section(
                  title: 'Security',
                  children: [
                    FutureBuilder<bool>(
                      future: _lockAvailable,
                      builder: (context, snapshot) {
                        final available = snapshot.data ?? false;
                        return SwitchListTile(
                          value: widget.settings.lockEnabled,
                          onChanged: available ? _toggleLock : null,
                          title: const Text('App lock'),
                          subtitle: Text(
                            available
                                ? 'Ask for your fingerprint, face or device PIN when Exposr opens '
                                    'or comes back from the background.'
                                : 'Set up a screen lock or biometrics on this device to use this.',
                          ),
                        );
                      },
                    ),
                  ],
                ),
                gap,
                _Section(
                  title: 'Your data',
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: Text(
                        'There are no accounts and no passwords. When you check an address, it is '
                        'sent over HTTPS to XposedOrNot and nowhere else; XposedOrNot’s own '
                        'privacy policy covers what happens to it there. Watchlist addresses and '
                        'these settings are saved in Exposr’s storage on this device. That storage '
                        'is not encrypted and a backup of your device may include it, so turn on '
                        'the app lock if others use this device.',
                        style: muted,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                      title: const Text('Clear all data'),
                      subtitle: const Text('Remove the watchlist and reset settings.'),
                      onTap: _clearAllData,
                    ),
                  ],
                ),
                gap,
                _Section(
                  title: 'About Exposr',
                  children: [
                    ListTile(
                      title: const Text('Version'),
                      trailing: Text(AppInfo.version, style: muted),
                    ),
                    ListTile(
                      title: const Text('Breach data'),
                      subtitle: const Text('Provided by XposedOrNot. Opens xposedornot.com.'),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () => _open(Uri.parse(AppInfo.providerSite), AppInfo.providerSiteLabel),
                    ),
                    ListTile(
                      title: const Text('Open-source licences'),
                      subtitle: const Text('Includes the Inter typeface and Flutter packages.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: AppInfo.name,
                        applicationVersion: AppInfo.version,
                        applicationLegalese: 'Breach data provided by XposedOrNot.',
                      ),
                    ),
                  ],
                ),
                gap,
                _DeveloperPanel(
                  onVisit: () => _open(Uri.parse(AppInfo.developerSite), AppInfo.developerSiteLabel),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Two buttons that play the feedback for each kind of result, exactly as a
/// real check would with the switches as they are now.
///
/// Nothing here plays unless a button is pressed.
class _FeedbackPreview extends StatelessWidget {
  const _FeedbackPreview({required this.feedback});

  final ResultFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final active = feedback.isActive;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            active
                ? 'Try the feedback for each result, with the switches as they are now.'
                : 'Turn on haptic feedback or result sounds to try them here.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              Semantics(
                label: 'Preview the feedback for breaches found',
                excludeSemantics: true,
                button: true,
                enabled: active,
                onTap: active ? () => feedback.give(CheckOutcome.breached) : null,
                child: OutlinedButton.icon(
                  onPressed: active ? () => feedback.give(CheckOutcome.breached) : null,
                  icon: const Icon(Icons.warning_amber_rounded, size: 18),
                  label: const Text('Breaches found'),
                ),
              ),
              Semantics(
                label: 'Preview the feedback for no known breaches',
                excludeSemantics: true,
                button: true,
                enabled: active,
                onTap: active ? () => feedback.give(CheckOutcome.clean) : null,
                child: OutlinedButton.icon(
                  onPressed: active ? () => feedback.give(CheckOutcome.clean) : null,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('No known breaches'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A titled group of settings rows in one panel, ruled between rows.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: SectionLabel(title),
        ),
        Panel(
          padding: EdgeInsets.zero,
          // The rows draw their hover and focus tints on this Material, and
          // the clip keeps those tints inside the rounded corners.
          child: ClipRRect(
            borderRadius: AppRadii.panelAll,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const Divider(),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "About the developer": who built the app, and a link to their website.
class _DeveloperPanel extends StatelessWidget {
  const _DeveloperPanel({required this.onVisit});

  final VoidCallback onVisit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('About the developer', style: textTheme.titleMedium),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Exposr is built by ${AppInfo.developerName}, a ${AppInfo.developerRole}. '
            'See more of my work on my website.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: onVisit,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Visit ${AppInfo.developerSiteLabel}'),
          ),
        ],
      ),
    );
  }
}
