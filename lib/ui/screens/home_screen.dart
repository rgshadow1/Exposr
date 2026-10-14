import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/breach_check_state.dart';
import '../../state/breach_check_controller.dart';
import '../widgets/attribution_footer.dart';
import '../widgets/breaches_found_view.dart';
import '../widgets/check_error_view.dart';
import '../widgets/email_form.dart';
import '../widgets/intro_panel.dart';
import '../widgets/no_breaches_view.dart';

/// The app's only screen: a form at the top, and below it whatever the
/// current [BreachCheckState] calls for.
///
/// Results are shown on the same screen instead of a pushed route so the
/// address stays visible and editable, and a new search is one tap away.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller, required this.config});

  final BreachCheckController controller;
  final AppConfig config;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Content never gets wider than this, so lines stay readable on tablets.
  static const double _maxContentWidth = 640;

  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();

  @override
  void dispose() {
    // Controllers and focus nodes hold resources and listeners; anything a
    // State creates, it must dispose.
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _startNewSearch() {
    widget.controller.reset();
    _emailController.clear();
    _emailFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 20.0;

            return SingleChildScrollView(
              // Dragging the list dismisses the keyboard, as users expect.
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(horizontalPadding, 32, horizontalPadding, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  // ListenableBuilder rebuilds only this subtree when the
                  // controller calls notifyListeners().
                  child: ListenableBuilder(
                    listenable: widget.controller,
                    builder: (context, _) => _buildContent(context, widget.controller.state),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, BreachCheckState state) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Breach Checker',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Check an email address', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'See whether it appears in known data breaches.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        EmailForm(
          controller: _emailController,
          focusNode: _emailFocus,
          isLoading: widget.controller.isLoading,
          onSubmit: widget.controller.check,
        ),
        const SizedBox(height: 28),
        // A short cross-fade between states. Keyed by state type, so it runs
        // when the kind of result changes, not on every rebuild.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, if (current != null) current],
          ),
          child: KeyedSubtree(
            key: ValueKey(state.runtimeType),
            child: _buildResult(state),
          ),
        ),
        const SizedBox(height: 32),
        const AttributionFooter(),
      ],
    );
  }

  Widget _buildResult(BreachCheckState state) {
    // Because BreachCheckState is sealed, this switch is exhaustive: add a new
    // state class and this line stops compiling until it's handled.
    return switch (state) {
      CheckIdle() => IntroPanel(config: widget.config),
      CheckLoading(:final email) => _CheckingIndicator(email: email),
      CheckBreachesFound(:final email, :final breaches) => BreachesFoundView(
          email: email,
          breaches: breaches,
          onNewSearch: _startNewSearch,
        ),
      CheckNoBreaches(:final email) => NoBreachesView(
          email: email,
          onNewSearch: _startNewSearch,
        ),
      CheckFailed(:final email, :final error) => CheckErrorView(
          error: error,
          onRetry: () => widget.controller.check(email),
          onNewSearch: _startNewSearch,
        ),
    };
  }
}

class _CheckingIndicator extends StatelessWidget {
  const _CheckingIndicator({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Checking $email…',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
