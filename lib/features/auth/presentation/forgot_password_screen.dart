import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../application/auth_providers.dart';
import '../domain/auth_error_messages.dart';
import '../domain/auth_validators.dart';
import 'widgets/auth_scaffold.dart';

/// Send-email-only password reset (milestone 3). Supabase mails a reset link
/// that opens its hosted page; there is no in-app new-password screen yet.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .sendResetEmail(_email.text.trim());

    if (!mounted) return;
    if (ref.read(authControllerProvider).hasError) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('If that email has an account, a reset link is on its way.'),
      ),
    );
    context.goNamed(AppRoutes.loginName);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
      }
    });
    final busy = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      title: 'Reset password',
      formKey: _formKey,
      children: [
        const Text(
          "Enter your email and we'll send a link to set a new password.",
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _email,
          enabled: !busy,
          autofillHints: const [AutofillHints.email],
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          validator: (value) => emailError(value ?? ''),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : _submit,
          child: busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send reset link'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy ? null : () => context.goNamed(AppRoutes.loginName),
          child: const Text('Back to log in'),
        ),
      ],
    );
  }
}
