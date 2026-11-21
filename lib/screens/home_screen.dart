import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_tokens.dart';
import '../services/link_opener.dart';
import '../state/email_check_controller.dart';
import '../widgets/app_page.dart';
import '../widgets/check_panel.dart';
import '../widgets/check_results.dart';
import '../widgets/radar_backdrop.dart';

/// The Home tab: the check panel, and under it the detail of the result.
///
/// Everything sits in one centered column no wider than
/// [AppSizes.contentWidth], at every window size. The panel is the obvious
/// first thing to use; results arrive beneath it and never push it around.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller, required this.links});

  final EmailCheckController controller;
  final LinkOpener links;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Putting the cursor in the field on arrival is helpful with a physical
  /// keyboard. On a phone or tablet it would throw the on-screen keyboard
  /// over the page, so it is left alone there.
  static bool get _hasPhysicalKeyboard {
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder tells us how much room we have so we can adapt to it.
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = AppPage.gutterFor(constraints.maxWidth);
        final wide = constraints.maxWidth >= 720;

        // The height this tab has been given shrinks when the on-screen
        // keyboard opens, on a phone held on its side, and in a short window.
        // Whichever it is, there is little room, so the panel shows only what
        // the field and button need.
        final short = constraints.maxHeight < 520;

        // On a tall window the panel sits a little lower, so the page doesn't
        // read as a strip of content above an empty screen.
        final lift = wide ? ((constraints.maxHeight - 760) * 0.25).clamp(0.0, 72.0) : 0.0;
        final top = wide ? AppSpacing.xxl + lift : AppSpacing.lg;

        return SingleChildScrollView(
          // Dragging the page dismisses the keyboard, as users expect.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(gutter, top, gutter, AppSpacing.xxxl),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (wide)
                // The rings are centred on the mark: the panel's top padding plus
                // half the mark's height below the top of the panel.
                Positioned(
                  top: -top,
                  left: -gutter,
                  right: -gutter,
                  child: RadarBackdrop(centerY: top + 40 + 56),
                ),
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AppSizes.contentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CheckPanel(
                        // A key keeps the typed address when the layout
                        // changes shape around it.
                        key: const GlobalObjectKey('check-panel'),
                        controller: widget.controller,
                        autofocus: _hasPhysicalKeyboard,
                        compact: short,
                      ),
                      // The gap belongs to the results, so it disappears with
                      // them when there is nothing to show.
                      _ResultsGap(controller: widget.controller),
                      CheckResults(controller: widget.controller, links: widget.links),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Space above the results, present only while there are results.
class _ResultsGap extends StatelessWidget {
  const _ResultsGap({required this.controller});

  final EmailCheckController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasDetail = switch (controller.state) {
          LookupIdle() || LookupLoading() => false,
          _ => true,
        };
        return SizedBox(height: hasDetail ? AppSpacing.xxl : 0);
      },
    );
  }
}
