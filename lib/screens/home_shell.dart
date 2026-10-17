import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/page_backdrop.dart';
import '../services/app_lock_service.dart';
import '../services/link_opener.dart';
import '../state/email_check_controller.dart';
import '../state/settings_controller.dart';
import '../state/watchlist_controller.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';
import 'watchlist_screen.dart';

/// The app's frame: a [Scaffold] holding the current tab and the bottom
/// navigation bar.
///
/// A Scaffold is Material's page skeleton. It has named slots (`body`,
/// `bottomNavigationBar`, `appBar`, ...) and lays them out for you, including
/// resizing the body when the keyboard opens.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.controller,
    required this.settings,
    required this.watchlist,
    required this.lock,
    required this.links,
  });

  /// Created once by the app and handed down to the screens that need it.
  final EmailCheckController controller;
  final SettingsController settings;
  final WatchlistController watchlist;
  final AppLockService lock;
  final LinkOpener links;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

// State: this class is the "memory" of the widget. It outlives rebuilds, and
// calling setState() tells Flutter the data changed so build() runs again.
class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Light status-bar icons, otherwise they can be dark-on-dark on Android.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.card,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      // The page background lives here, behind everything, and listens to the
      // controller so it can shift colour with the result. The Scaffold on top
      // is made transparent so this shows through.
      //
      // ListenableBuilder's `child` is built once and handed back to the
      // builder, so a change of colour doesn't rebuild the whole screen.
      child: ListenableBuilder(
        listenable: widget.controller,
        child: _buildScaffold(),
        builder: (context, child) {
          // The tint belongs to the Home tab, where the result is shown.
          final backdrop = _selectedIndex == 0
              ? PageBackdrop.forState(widget.controller.state)
              : PageBackdrop.neutral;

          // AnimatedContainer animates between its old and new decoration by
          // itself: change the gradient and it fades over `duration`.
          return AnimatedContainer(
            key: const Key('page-background'),
            // People who turn off animations in system settings get an instant
            // change instead of a fade.
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(gradient: backdrop.gradient),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // SafeArea keeps content clear of the notch and status bar. The bottom
      // is skipped because NavigationBar handles its own bottom inset.
      body: SafeArea(
        bottom: false,
        // IndexedStack keeps the Home tab alive while you visit another, so
        // the typed address and the results are still there when you come back.
        // The other tabs are built only while they are showing: they keep their
        // data in the controllers, and building them fresh means their
        // animations play each time you open them.
        child: IndexedStack(
          index: _selectedIndex,
          sizing: StackFit.expand,
          children: [
            HomeScreen(controller: widget.controller),
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
                lock: widget.lock,
                links: widget.links,
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        // The Watchlist icon carries a badge while there are new breaches the
        // user hasn't looked at.
        child: ListenableBuilder(
          listenable: widget.watchlist,
          builder: (context, _) {
            final newBreaches = widget.watchlist.newBreachCount;

            return NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: 'Insights',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: newBreaches > 0,
                    label: Text('$newBreaches'),
                    child: const Icon(Icons.visibility_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: newBreaches > 0,
                    label: Text('$newBreaches'),
                    child: const Icon(Icons.visibility),
                  ),
                  label: 'Watchlist',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
