import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() =>
      _RegisterPageState();
}

class _RegisterPageState
    extends ConsumerState<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController =
      TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _register() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    await ref
        .read(authControllerProvider.notifier)
        .signUp(
          email,
          password,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    final isLoading =
        authState.status == AuthStatus.authenticating;

    final confirmationRequired =
        authState.status ==
            AuthStatus.emailConfirmationRequired;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      confirmationRequired
                          ? 'Check your email'
                          : 'Create your account',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      confirmationRequired
                          ? 'We sent you a confirmation link. Confirm your email to activate your account.'
                          : 'Join Linsy and listen together',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge,
                    ),

                    const SizedBox(height: 32),

                    if (!confirmationRequired) ...[
                      TextFormField(
                        controller: _emailController,
                        enabled: !isLoading,
                        keyboardType:
                            TextInputType.emailAddress,
                        textInputAction:
                            TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.email,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final email =
                              value?.trim() ?? '';

                          if (email.isEmpty) {
                            return 'Enter your email';
                          }

                          final emailRegex = RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          );

                          if (!emailRegex
                              .hasMatch(email)) {
                            return 'Enter a valid email';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller:
                            _passwordController,
                        enabled: !isLoading,
                        obscureText:
                            _obscurePassword,
                        textInputAction:
                            TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.newPassword,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border:
                              const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _obscurePassword =
                                          !_obscurePassword;
                                    });
                                  },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                          ),
                        ),
                        validator: (value) {
                          final password =
                              value ?? '';

                          if (password.isEmpty) {
                            return 'Enter a password';
                          }

                          if (password.length < 6) {
                            return 'Password must be at least 6 characters';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller:
                            _confirmPasswordController,
                        enabled: !isLoading,
                        obscureText:
                            _obscureConfirmPassword,
                        textInputAction:
                            TextInputAction.done,
                        autofillHints: const [
                          AutofillHints.newPassword,
                        ],
                        onFieldSubmitted: (_) =>
                            _register(),
                        decoration: InputDecoration(
                          labelText: 'Confirm password',
                          border:
                              const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            tooltip:
                                _obscureConfirmPassword
                                    ? 'Show password'
                                    : 'Hide password',
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty) {
                            return 'Confirm your password';
                          }

                          if (value !=
                              _passwordController
                                  .text) {
                            return 'Passwords do not match';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      if (authState.errorMessage !=
                          null) ...[
                        Align(
                          alignment:
                              Alignment.centerLeft,
                          child: Text(
                            authState.errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .error,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: isLoading
                              ? null
                              : _register,
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Create account',
                                ),
                        ),
                      ),
                    ],

                    if (confirmationRequired)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                             ref.read(authControllerProvider.notifier).clearEmailConfirmation();
                             context.go('/login');
                          },
                          child: const Text(
                            'Back to sign in',
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium,
                        ),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                   ref.read(authControllerProvider.notifier).clearEmailConfirmation();
                                   ref
                                      .read(authControllerProvider.notifier)
                                      .clearAuthError();
                                  context.go('/login');
                                },
                          child: const Text(
                            'Sign in',
                          ),
                        ),
                      ],
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