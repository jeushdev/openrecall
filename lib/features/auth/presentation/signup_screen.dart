import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../application/auth_providers.dart';
import '../domain/auth_error_messages.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/email_password_fields.dart';

/// Email + password account creation. Email confirmation is disabled for the
/// beta, so a successful sign-up establishes a session and the router's
/// redirect moves the user straight to the Deck Library.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).signUp(
          email: _email.text.trim(),
          password: _password.text,
        );
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
      title: 'Create account',
      formKey: _formKey,
      children: [
        EmailPasswordFields(
          emailController: _email,
          passwordController: _password,
          enabled: !busy,
          passwordHint: 'At least 6 characters',
          onSubmit: _submit,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : _submit,
          child: busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Sign up'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy ? null : () => context.goNamed(AppRoutes.loginName),
          child: const Text('I already have an account'),
        ),
      ],
    );
  }
}
