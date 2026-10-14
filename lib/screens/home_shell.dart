import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/page_backdrop.dart';
import '../state/email_check_controller.dart';
import '../widgets/placeholder_screen.dart';
import 'home_screen.dart';

/// The app's frame: a [Scaffold] holding the current tab and the bottom
/// navigation bar.
///
/// A Scaffold is Material's page skeleton. It has named slots (`body`,
/// `bottomNavigationBar`, `appBar`, ...) and lays them out for you, including
/// resizing the body when the keyboard opens.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  /// Created once by the app and handed down to the screens that need it.
  final EmailCheckController controller;

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
        // IndexedStack builds every tab once and shows one, so each tab
        // keeps its state (like typed text) while you visit another.
        child: IndexedStack(
          index: _selectedIndex,
          sizing: StackFit.expand,
          children: [
            HomeScreen(controller: widget.controller),
            const PlaceholderScreen(
              icon: Icons.history,
              title: 'History',
              message: 'Nothing to show yet. This screen is a placeholder for a later step.',
            ),
            const PlaceholderScreen(
              icon: Icons.settings_outlined,
              title: 'Settings',
              message: 'Nothing to show yet. This screen is a placeholder for a later step.',
            ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.history),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
