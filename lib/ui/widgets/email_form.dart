import 'package:flutter/material.dart';

import '../../utils/email_validator.dart';

/// The email field and "Check" button.
///
/// The text controller and focus node are owned by the screen and passed in,
/// because the screen needs to clear and focus the field when the user starts
/// a new search. This widget only handles input and validation.
class EmailForm extends StatefulWidget {
  const EmailForm({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;

  /// Called with the trimmed address once it passes validation.
  final ValueChanged<String> onSubmit;

  @override
  State<EmailForm> createState() => _EmailFormState();
}

class _EmailFormState extends State<EmailForm> {
  /// A GlobalKey gives us access to the [FormState], which runs every
  /// field's validator when we call `validate()`.
  final _formKey = GlobalKey<FormState>();

  /// Errors appear only after the first submit attempt, then update as the
  /// user types. Showing "invalid email" while someone is halfway through
  /// typing it is just noise.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  void _submit() {
    if (widget.isLoading) return;

    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      widget.onSubmit(widget.controller.text.trim());
    } else {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: _autovalidateMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            enabled: !widget.isLoading,
            validator: EmailValidator.validate,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            enableSuggestions: false,
            // Lets the keyboard offer the user's own addresses. The app itself
            // never stores what is typed here.
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Email address',
              hintText: 'name@example.com',
              prefixIcon: Icon(Icons.alternate_email),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: widget.isLoading ? null : _submit,
            child: widget.isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      semanticsLabel: 'Checking',
                    ),
                  )
                : const Text('Check'),
          ),
        ],
      ),
    );
  }
}
