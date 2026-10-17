import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/lottie_assets.dart';
import '../widgets/exposr_lottie.dart';

/// What you see while the app is locked: the shield, one sentence, and a button
/// to try again. The unlock prompt appears by itself as soon as this shows.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlock, this.failed = false});

  /// Starts the system prompt (fingerprint, face or PIN).
  final VoidCallback onUnlock;

  /// True after an attempt that didn't unlock, so the screen can say so.
  final bool failed;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  @override
  void initState() {
    super.initState();
    // Ask once the screen is on display, not in the middle of building it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onUnlock();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: ExposrLottie(asset: LottieAssets.shield, size: 150)),
                  const SizedBox(height: 16),
                  Text('Exposr is locked', textAlign: TextAlign.center, style: textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    widget.failed
                        ? 'That didn’t work. Try again with your fingerprint, face or device PIN.'
                        : 'Use your fingerprint, face or device PIN to continue.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: widget.onUnlock,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Unlock'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
