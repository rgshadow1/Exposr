import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_tokens.dart';
import '../state/email_check_controller.dart';
import '../utils/email_validator.dart';
import '../utils/failure_text.dart';
import 'check_mark.dart';
import 'how_it_works.dart';
import 'inline_progress.dart';
import 'panel.dart';

/// The focal point of the Home screen: one surface holding the mark, a short
/// heading, a line of supporting text, the email field and the primary action.
///
/// It is also where the verdict appears. The mark and the heading follow the
/// check ("Is your email exposed?", then "Searching…", then "Found in 3 known
/// breaches"), so the outcome and the affected address are the first thing seen
/// after pressing the button, in the same spot, without scrolling. The panel's
/// parts keep their sizes from state to state, so nothing moves under a
/// finger while a check runs or a result lands.
///
/// The primary action follows the state too:
///
///  * ready: "Check for breaches";
///  * running: "Checking…", disabled, so a second request can't be started;
///  * done: "Check another address", which clears everything and goes back to
///    the field, without spending a request;
///  * failed: "Try again", which repeats the same check.
///
/// It owns only what belongs to the form: the text being typed and whether to
/// show validation errors yet. The lookup lives in the [EmailCheckController]
/// and the detail under the panel is drawn by `CheckResults`.
///
/// It is a [StatefulWidget] because the text controller must outlive rebuilds
/// (a StatelessWidget would lose what you typed every time it rebuilt).
class CheckPanel extends StatefulWidget {
  const CheckPanel({
    super.key,
    required this.controller,
    this.autofocus = false,
    this.compact = false,
  });

  final EmailCheckController controller;

  /// Not much height to spare (a phone with the on-screen keyboard up, or on
  /// its side): shrink the mark and drop the supporting line, so the field and
  /// the button stay in view.
  ///
  /// The screen decides this from the height it has been given. The keyboard's
  /// own inset can't be used: the Scaffold consumes it before it gets here.
  final bool compact;

  /// Focus the field as soon as it appears. Only sensible where that doesn't
  /// throw an on-screen keyboard over the page.
  final bool autofocus;

  static const String fieldLabel = 'Email address';
  static const String submitLabel = 'Check for breaches';
  static const String checkAnotherLabel = 'Check another address';
  static const String retryLabel = 'Try again';

  @override
  State<CheckPanel> createState() => _CheckPanelState();
}

class _CheckPanelState extends State<CheckPanel> {
  /// A key that lets us reach the [FormState] to run validation on demand.
  final _formKey = GlobalKey<FormState>();

  /// Owns the text in the field, so we can read it and clean it up.
  final _emailController = TextEditingController();

  final _focus = FocusNode(debugLabel: 'email');

  /// Errors appear only after the first failed attempt, then update as the
  /// user types. Flagging "invalid" while someone is halfway through typing an
  /// address is just noise.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    widget.controller.inputWipes.addListener(_onWipe);
  }

  @override
  void didUpdateWidget(CheckPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.inputWipes.removeListener(_onWipe);
      widget.controller.inputWipes.addListener(_onWipe);
    }
  }

  @override
  void dispose() {
    // Anything a State creates, it must dispose, or it leaks.
    widget.controller.inputWipes.removeListener(_onWipe);
    _emailController.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Something asked for the typed address to go ("Shake to hide", "Clear all
  /// data", "Check another address").
  void _onWipe() {
    _emailController.clear();
    setState(() => _autovalidateMode = AutovalidateMode.disabled);
  }

  void _onEmailChanged(String _) {
    // Editing makes the previous result out of date, so clear it. (While a
    // lookup is running the field is read-only, so this can't fire then.)
    final state = widget.controller.state;
    if (state is! LookupIdle && state is! LookupLoading) {
      widget.controller.reset();
    }
  }

  /// Runs from the button and from Enter in the field.
  void _submit() {
    // A check is already running: one request per press, never two.
    if (widget.controller.isLoading) return;

    // Input validation: validate() runs every field's validator in the Form
    // and shows the returned message under the field. null means "valid".
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }

    FocusScope.of(context).unfocus(); // close the keyboard
    widget.controller.check(_emailController.text.trim());
  }

  void _retry(String email) {
    if (widget.controller.isLoading) return;
    widget.controller.check(email);
  }

  /// Back to a blank form, with the cursor in the field.
  void _checkAnother() {
    widget.controller.wipe();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final roomy = constraints.maxWidth >= 520;
        final compact = widget.compact;

        return Panel(
          padding: roomy
              ? const EdgeInsets.fromLTRB(32, 40, 32, 20)
              : const EdgeInsets.fromLTRB(20, 28, 20, 12),
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidateMode,
            // Only this subtree rebuilds when a lookup starts or finishes.
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final state = widget.controller.state;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(state: state, roomy: roomy, compact: compact),
                    SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
                    _field(context, state),
                    const SizedBox(height: AppSpacing.md),
                    _action(state),
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(),
                    const SizedBox(height: AppSpacing.xs),
                    const HowItWorks(),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _field(BuildContext context, LookupState state) {
    final textTheme = Theme.of(context).textTheme;

    // The label stays above the field at all times. Screen readers get it
    // from the Semantics wrapper around the field instead, so it is read
    // once, as the field's name.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(child: Text(CheckPanel.fieldLabel, style: textTheme.labelMedium)),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: CheckPanel.fieldLabel,
          child: TextFormField(
            controller: _emailController,
            focusNode: _focus,
            autofocus: widget.autofocus,
            // readOnly (not enabled: false) keeps the field's normal look
            // while the lookup runs.
            readOnly: state is LookupLoading,
            validator: EmailValidator.validate,
            onChanged: _onEmailChanged,
            // Enter submits, exactly like the button.
            onFieldSubmitted: (_) => _submit(),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.search,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            enableSuggestions: false,
            style: textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'you@example.com',
              prefixIcon: Icon(Icons.alternate_email, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _action(LookupState state) {
    const secondaryStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size.fromHeight(AppSizes.controlHeight)),
    );

    return switch (state) {
      LookupIdle() => FilledButton(
          onPressed: _submit,
          child: const Text(CheckPanel.submitLabel),
        ),
      // onPressed: null disables the button, which blocks double taps.
      LookupLoading() => const FilledButton(
          onPressed: null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Spinner(color: AppColors.onPrimary),
              SizedBox(width: 10),
              Text('Checking…'),
            ],
          ),
        ),
      LookupFailed(:final email) => FilledButton(
          onPressed: () => _retry(email),
          child: const Text(CheckPanel.retryLabel),
        ),
      LookupBreached() || LookupClean() => OutlinedButton(
          onPressed: _checkAnother,
          style: secondaryStyle,
          child: const Text(CheckPanel.checkAnotherLabel),
        ),
    };
  }
}

/// The mark, the heading and the line under it, for whatever state the check
/// is in.
class _Header extends StatelessWidget {
  const _Header({required this.state, required this.roomy, required this.compact});

  final LookupState state;
  final bool roomy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // On a phone the idle heading breaks onto two lines on purpose, and the
    // heading area always has room for two. The verdicts are too long for one
    // line at that width, and this way the field doesn't move when they land.
    final twoLineTitle = !roomy && !compact;
    final copy = _HeaderCopy.of(state, breakTitle: twoLineTitle);

    final markSize = compact ? 56.0 : (roomy ? 112.0 : 96.0);
    final titleStyle = roomy ? textTheme.headlineMedium : textTheme.headlineSmall;
    final bodyStyle = textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary);

    final scaler = MediaQuery.textScalerOf(context);
    final titleLine = scaler.scale(titleStyle?.fontSize ?? 24) * (titleStyle?.height ?? 1.25);
    // The line under the title always takes two lines of room too, so the
    // field below stays where it is whichever state the panel is in.
    final twoLines = scaler.scale((bodyStyle?.fontSize ?? 15) * 1.55) * 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: markSize, child: Center(child: CheckMark(state: state, size: markSize))),
        SizedBox(height: compact ? AppSpacing.xs : AppSpacing.md),
        // liveRegion: screen readers announce the verdict when it appears.
        Semantics(
          container: true,
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: twoLineTitle ? titleLine * 2 : 0),
                child: Center(
                  child: Semantics(
                    header: true,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: copy.title),
                          if (copy.accent != null)
                            TextSpan(
                              text: copy.accent,
                              style: const TextStyle(color: AppColors.accent),
                            ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: titleStyle,
                    ),
                  ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: twoLines),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (copy.email != null)
                          TextSpan(
                            text: copy.email,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (copy.email != null) const TextSpan(text: '\n'),
                        TextSpan(text: copy.detail),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: bodyStyle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The words for each state.
class _HeaderCopy {
  const _HeaderCopy({required this.title, this.accent, this.email, required this.detail});

  final String title;

  /// The end of the title, set in the accent colour.
  final String? accent;
  final String? email;
  final String detail;

  /// [breakTitle] puts the idle heading on two lines ("Is your email" over
  /// "exposed?"), which is how a phone shows it.
  static _HeaderCopy of(LookupState state, {required bool breakTitle}) {
    return switch (state) {
      LookupIdle() => _HeaderCopy(
          title: breakTitle ? 'Is your email\n' : 'Is your email ',
          accent: 'exposed?',
          // Balanced over two lines on a phone, so no word is left alone.
          detail: breakTitle
              ? 'Check an address against\nknown data breaches.'
              : 'Check an address against known data breaches.',
        ),
      LookupLoading(:final email) => _HeaderCopy(
          title: 'Searching known breaches…',
          email: email,
          detail: 'Asking XposedOrNot.',
        ),
      LookupBreached(:final email, :final breachNames) => _HeaderCopy(
          title: 'Found in ${breachNames.length} known '
              '${breachNames.length == 1 ? 'breach' : 'breaches'}',
          email: email,
          detail: 'Seen in XposedOrNot’s data.',
        ),
      LookupClean(:final email) => _HeaderCopy(
          title: 'No known breaches found',
          email: email,
          detail: 'Not in XposedOrNot’s data.',
        ),
      LookupFailed(:final email, :final failure) => _HeaderCopy(
          title: failureTitle(failure),
          email: email,
          detail: 'The check didn’t finish.',
        ),
    };
  }
}
