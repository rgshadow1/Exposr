import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_info.dart';
import '../core/lottie_assets.dart';
import '../services/app_lock_service.dart';
import '../services/link_opener.dart';
import '../state/email_check_controller.dart';
import '../state/settings_controller.dart';
import '../state/watchlist_controller.dart';
import '../widgets/exposr_lottie.dart';
import '../widgets/screen_header.dart';

/// The Settings tab: feedback and security switches, what the app does with
/// data, and the About sections.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.watchlist,
    required this.lookup,
    required this.lock,
    required this.links,
  });

  final SettingsController settings;
  final WatchlistController watchlist;
  final EmailCheckController lookup;
  final AppLockService lock;
  final LinkOpener links;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const double _maxContentWidth = 560;

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

  Future<void> _openDeveloperSite() async {
    final opened = await widget.links.open(Uri.parse(AppInfo.developerSite));
    if (!opened && mounted) {
      _snack('Couldn’t open the link. You can find it at ${AppInfo.developerSiteLabel}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 20.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: ListenableBuilder(
                listenable: widget.settings,
                builder: (context, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ScreenHeader(
                        title: 'Settings',
                        subtitle: 'Feedback, security and what Exposr does with your data.',
                      ),
                      const SizedBox(height: 24),
                      _Section(
                        title: 'Feedback',
                        children: [
                          SwitchListTile(
                            value: widget.settings.hapticsEnabled,
                            onChanged: widget.settings.setHapticsEnabled,
                            title: const Text('Vibrate on results'),
                            subtitle: Text(
                              'A firm double pulse for breaches, a soft tap when nothing is found, a click for errors.',
                              style: muted,
                            ),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            value: widget.settings.shakeToHideEnabled,
                            onChanged: widget.settings.setShakeToHideEnabled,
                            title: const Text('Shake to hide'),
                            subtitle: Text(
                              'Shake your phone to clear the address and results from the screen, '
                              'in case someone is looking over your shoulder.',
                              style: muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
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
                                  style: muted,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _Section(
                        title: 'Your data',
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'There are no accounts and no passwords. When you check an address, it is sent '
                              'over HTTPS to XposedOrNot and nowhere else. Watchlist addresses and these '
                              'settings are saved on this device only. The saved list is not encrypted, so '
                              'turn on the app lock if others use your phone.',
                              style: muted,
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.delete_outline, color: AppColors.error),
                            title: const Text('Clear all data'),
                            subtitle: Text('Remove the watchlist and reset settings.', style: muted),
                            onTap: _clearAllData,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _Section(
                        title: 'About Exposr',
                        children: [
                          ListTile(
                            title: const Text('Version'),
                            trailing: Text(AppInfo.version, style: muted),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            title: const Text('Breach data'),
                            trailing: Text('XposedOrNot', style: muted),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            title: const Text('Open-source licences'),
                            subtitle: Text('Includes the Inter typeface and Flutter packages.', style: muted),
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
                      const SizedBox(height: 20),
                      _DeveloperCard(onVisit: _openDeveloperSite),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A titled group of settings rows in one card.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Semantics(
            header: true,
            child: Text(
              title.toUpperCase(),
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

/// "About the developer": who built the app, and a link to their website.
class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard({required this.onVisit});

  final VoidCallback onVisit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: ExposrLottie(asset: LottieAssets.shield, size: 84)),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              child: Text(
                'About the developer',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Exposr is built by ${AppInfo.developerName}, a ${AppInfo.developerRole}. '
              'See more of my work on my website.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onVisit,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Visit ${AppInfo.developerSiteLabel}'),
            ),
          ],
        ),
      ),
    );
  }
}
