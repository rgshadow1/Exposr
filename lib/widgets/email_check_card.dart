import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../state/email_check_controller.dart';
import '../utils/email_validator.dart';
import 'icon_badge.dart';

/// The main card: an email field, a "Check Email" button and a privacy note.
///
/// It owns only what belongs to the form itself: the text being typed and
/// whether to show validation errors yet. The lookup and its results live in
/// the [EmailCheckController], and the results are drawn by `CheckResults`.
///
/// It is a [StatefulWidget] because the text controller must outlive rebuilds
/// (a StatelessWidget would lose what you typed every time it rebuilt).
class EmailCheckCard extends StatefulWidget {
  const EmailCheckCard({super.key, required this.controller});

  final EmailCheckController controller;

  @override
  State<EmailCheckCard> createState() => _EmailCheckCardState();
}

class _EmailCheckCardState extends State<EmailCheckCard> {
  /// A key that lets us reach the [FormState] to run validation on demand.
  final _formKey = GlobalKey<FormState>();

  /// Owns the text in the field, so we can read it and clean it up.
  final _emailController = TextEditingController();

  /// Errors appear only after the first failed attempt, then update as the
  /// user types. Flagging "invalid" while someone is halfway through typing an
  /// address is just noise.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    // Anything a State creates, it must dispose, or it leaks.
    _emailController.dispose();
    super.dispose();
  }

  void _onEmailChanged(String _) {
    // Editing makes the previous result out of date, so clear it. (While a
    // lookup is running the field is read-only, so this can't fire then.)
    final state = widget.controller.state;
    if (state is! LookupIdle && state is! LookupLoading) {
      widget.controller.reset();
    }
  }

  void _submit() {
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidateMode,
          // The card rebuilds when the controller changes, so the field locks
          // and the button shows a spinner while a lookup is running.
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final isLoading = widget.controller.isLoading;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const IconBadge(icon: Icons.mark_email_unread_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Check an email address', style: textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              'See whether it appears in known data breaches.',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    // readOnly (not enabled: false) keeps the field's normal
                    // look while the lookup runs.
                    readOnly: isLoading,
                    validator: EmailValidator.validate,
                    onChanged: _onEmailChanged,
                    onFieldSubmitted: (_) => _submit(),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      hintText: 'name@example.com',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // onPressed: null disables the button, which blocks double taps.
                  FilledButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppColors.onPrimary,
                                  semanticsLabel: 'Checking',
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Checking…'),
                            ],
                          )
                        : const Text('Check Email'),
                  ),
                  const SizedBox(height: 14),
                  // Accurate by construction: it says where the address goes,
                  // and what this app does (and doesn't do) with it.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The address is sent over HTTPS to XposedOrNot to run the '
                          'check. This app doesn’t store it. Only check addresses '
                          'you own or have permission to check.',
                          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
