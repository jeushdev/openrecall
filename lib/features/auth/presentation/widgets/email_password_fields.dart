import 'package:flutter/material.dart';

import '../../domain/auth_validators.dart';

/// The email + password pair shared by the Login and Sign-up screens, so the
/// two cannot drift apart. Wrap in a [Form] and supply the controllers.
class EmailPasswordFields extends StatefulWidget {
  const EmailPasswordFields({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.enabled,
    this.passwordHint,
    this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool enabled;

  /// Helper text under the password field (e.g. the minimum length on sign-up).
  final String? passwordHint;

  /// Invoked when the user presses "done" on the password field.
  final VoidCallback? onSubmit;

  @override
  State<EmailPasswordFields> createState() => _EmailPasswordFieldsState();
}

class _EmailPasswordFieldsState extends State<EmailPasswordFields> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: widget.emailController,
          enabled: widget.enabled,
          autofillHints: const [AutofillHints.email],
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Email'),
          validator: (value) => emailError(value ?? ''),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.passwordController,
          enabled: widget.enabled,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => widget.onSubmit?.call(),
          decoration: InputDecoration(
            labelText: 'Password',
            helperText: widget.passwordHint,
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              tooltip: _obscure ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: (value) => passwordError(value ?? ''),
        ),
      ],
    );
  }
}
