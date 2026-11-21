import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/app_tokens.dart';
import '../services/app_lock_service.dart';
import '../services/link_opener.dart';
import '../state/email_check_controller.dart';
import '../state/result_feedback.dart';
import '../state/settings_controller.dart';
import '../state/watchlist_controller.dart';
import '../widgets/app_navigation.dart';
import '../widgets/brand_mark.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';
import 'watchlist_screen.dart';

/// The app's frame: the current tab, and the navigation that suits the
/// window it is in.
///
///  * Phones get a bottom bar.
///  * Mid-sized windows get a slim rail down the left.
///  * Wide windows get a labelled sidebar.
///
/// The layout is chosen from the width alone, so it follows a window as it is
/// resized and a tablet as it is rotated.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.controller,
    required this.settings,
    required this.watchlist,
    required this.feedback,
    required this.lock,
    required this.links,
  });

  /// Created once by the app and handed down to the screens that need it.
  final EmailCheckController controller;
  final SettingsController settings;
  final WatchlistController watchlist;
  final ResultFeedback feedback;
  final AppLockService lock;
  final LinkOpener links;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

// State: this class is the "memory" of the widget. It outlives rebuilds, and
// calling setState() tells Flutter the data changed so build() runs again.
class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  /// Keeps the tabs' state (the typed address, scroll positions) when the
  /// frame around them changes shape, for example when a window is resized
  /// from phone width to desktop width.
  final GlobalKey _tabsKey = GlobalKey(debugLabel: 'tabs');

  void _select(int index) {
    if (index != _selectedIndex) setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Light status-bar icons, otherwise they can be dark-on-dark on Android.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      // LayoutBuilder tells us how much room we have so we can adapt to it.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = AppLayout.forWidth(constraints.maxWidth);
          final tabs = KeyedSubtree(key: _tabsKey, child: _buildTabs());

          // Only the navigation listens to the watchlist (for its badge).
          // `tabs` is built once per layout pass and handed back to the
          // builder, so a badge change doesn't rebuild the screens.
          return ListenableBuilder(
            listenable: widget.watchlist,
            child: tabs,
            builder: (context, child) {
              final newBreaches = widget.watchlist.newBreachCount;

              return switch (layout) {
                AppLayout.compact => Scaffold(
                    // SafeArea keeps content clear of the notch and status
                    // bar. The bottom is skipped because NavigationBar
                    // handles its own bottom inset.
                    body: SafeArea(
                      bottom: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [const _TopBar(), Expanded(child: child!)],
                      ),
                    ),
                    bottomNavigationBar: AppBottomBar(
                      selectedIndex: _selectedIndex,
                      onSelected: _select,
                      newBreaches: newBreaches,
                    ),
                  ),
                AppLayout.medium => Scaffold(
                    body: SafeArea(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppNavRail(
                            selectedIndex: _selectedIndex,
                            onSelected: _select,
                            newBreaches: newBreaches,
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: child!),
                        ],
                      ),
                    ),
                  ),
                AppLayout.expanded => Scaffold(
                    body: SafeArea(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppSidebar(
                            selectedIndex: _selectedIndex,
                            onSelected: _select,
                            newBreaches: newBreaches,
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: child!),
                        ],
                      ),
                    ),
                  ),
              };
            },
          );
        },
      ),
    );
  }

  Widget _buildTabs() {
    // IndexedStack keeps the Home tab alive while you visit another, so the
    // typed address and the results are still there when you come back. The
    // other tabs are built only while they are showing: they keep their data
    // in the controllers, so there is nothing to lose.
    return IndexedStack(
      index: _selectedIndex,
      sizing: StackFit.expand,
      children: [
        // Kept alive while hidden, but not drawing: an IndexedStack doesn't
        // pause its hidden children's animations, so without this a looping
        // animation would keep running behind the tab that is showing.
        TickerMode(
          enabled: _selectedIndex == 0,
          child: HomeScreen(controller: widget.controller, links: widget.links),
        ),
        if (_selectedIndex == 1)
          InsightsScreen(controller: widget.controller)
        else
          const SizedBox.shrink(),
        if (_selectedIndex == 2)
          WatchlistScreen(watchlist: widget.watchlist)
        else
          const SizedBox.shrink(),
        if (_selectedIndex == 3)
          SettingsScreen(
            settings: widget.settings,
            watchlist: widget.watchlist,
            lookup: widget.controller,
            feedback: widget.feedback,
            lock: widget.lock,
            links: widget.links,
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}

/// The logo and name across the top of a phone screen. On wider layouts the
/// rail or sidebar carries the logo instead.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, AppSpacing.md, 20, AppSpacing.xs),
      child: Align(alignment: Alignment.centerLeft, child: BrandMark(size: 26)),
    );
  }
}
