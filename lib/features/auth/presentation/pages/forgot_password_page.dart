import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(_emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.authenticating;

    final sent = authState.status == AuthStatus.passwordResetRequested;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sent ? 'Check your email' : 'Reset your password',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      sent
                          ? 'We sent you a password reset link on your email. Please check your inbox and follow the instructions to reset your password.'
                          : 'Enter your email and we will send you a reset link.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    if (!sent) ...[
                      TextFormField(
                        controller: _emailController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';

                          if (email.isEmpty) {
                            return 'Enter your email';
                          }

                          final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

                          if (!regex.hasMatch(email)) {
                            return 'Enter a valid email';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      if (authState.errorMessage != null) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            authState.errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: isLoading ? null : _sendResetLink,
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Send reset link'),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    if (!sent)
                      TextButton.icon(
                        onPressed: isLoading
                            ? null
                            : () {
                                context.go('/login');
                              },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to sign in'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
