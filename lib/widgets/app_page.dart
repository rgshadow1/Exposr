import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_tokens.dart';
import '../core/lottie_assets.dart';
import 'exposr_lottie.dart';

/// The frame every tab shares: a scrolling column, capped in width and padded
/// to suit the space it is given, optionally under a title.
///
/// Content is left-aligned and starts at the same place on every screen, so
/// moving between tabs doesn't shift the eye.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.children,
    this.title,
    this.subtitle,
    this.maxWidth = AppSizes.readingWidth,
    this.controller,
  });

  final String? title;
  final String? subtitle;
  final double maxWidth;
  final List<Widget> children;
  final ScrollController? controller;

  /// The gutter either side of the content, for a page [width] wide.
  static double gutterFor(double width) {
    if (width < 600) return 20;
    if (width < 1024) return AppSpacing.xxl;
    return AppSpacing.xxxl;
  }

  @override
  Widget build(BuildContext context) {
    final title = this.title;

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = gutterFor(constraints.maxWidth);
        final top = constraints.maxWidth < 600 ? AppSpacing.lg : AppSpacing.xxl + AppSpacing.sm;

        return SingleChildScrollView(
          controller: controller,
          // Dragging the page dismisses the keyboard, as users expect.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(gutter, top, gutter, AppSpacing.xxxl),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null) ...[
                    PageHeader(title: title, subtitle: subtitle),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  ...children,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A page's title and the one line under it.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = this.subtitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: textTheme.headlineSmall)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle, style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}

/// What a screen shows when it has nothing to show yet: a mark, a title, one
/// or two sentences and, sometimes, the action that fixes it.
///
/// The mark is the shield-and-eye animation by default (it draws itself once),
/// the radar sweep while something is loading, or a plain still icon for a
/// problem.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon = Icons.shield_outlined,
    this.animation = LottieAssets.shield,
    this.loop = false,
    required this.title,
    required this.message,
    this.action,
    this.tone,
  });

  /// The still stand-in, and the icon itself when [animation] is null.
  final IconData icon;

  /// A Lottie file for the mark, or null for a still icon.
  final String? animation;

  /// Keep playing the animation for as long as it is shown (for loading).
  final bool loop;
  final String title;
  final String message;
  final Widget? action;

  /// Colours the still icon. Leave null for an ordinary "nothing here yet".
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final action = this.action;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadii.panelAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _mark(),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message, style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            if (action != null) ...[const SizedBox(height: AppSpacing.xl), action],
          ],
        ),
      ),
    );
  }

  Widget _mark() {
    final file = animation;
    if (file == null) {
      return ExcludeSemantics(child: Icon(icon, size: 28, color: tone ?? AppColors.textMuted));
    }
    return ExposrLottie(
      asset: file,
      size: 64,
      overscan: 1.45,
      loop: loop,
      restAt: 1,
      fallback: Icon(icon, size: 28, color: tone ?? AppColors.textMuted),
    );
  }
}
