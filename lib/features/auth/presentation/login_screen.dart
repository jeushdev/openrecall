import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../application/auth_providers.dart';
import '../domain/auth_error_messages.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/email_password_fields.dart';

/// Email + password sign-in. On success the router's redirect moves the user
/// to the Deck Library, so this screen only navigates for the secondary links.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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
    await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text.trim(), password: _password.text);
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
      title: 'Log in',
      formKey: _formKey,
      children: [
        EmailPasswordFields(
          emailController: _email,
          passwordController: _password,
          enabled: !busy,
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
              : const Text('Log in'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy
              ? null
              : () => context.goNamed(AppRoutes.forgotPasswordName),
          child: const Text('Forgot password?'),
        ),
        TextButton(
          onPressed: busy ? null : () => context.goNamed(AppRoutes.signupName),
          child: const Text('Create account'),
        ),
      ],
    );
  }
}
