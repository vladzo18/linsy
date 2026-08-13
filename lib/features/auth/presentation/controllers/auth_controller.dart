import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_repository_provider.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repository;

  StreamSubscription<AppUser?>? _authSubscription;

  @override
  AuthState build() {
    _repository = ref.read(authRepositoryProvider);

    _initialize();

    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    return const AuthState.initializing();
  }

  Future<void> _initialize() async {
    try {
      final user = await _repository.getCurrentUser();

      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = const AuthState.unauthenticated();
      }

      _authSubscription = _repository.authStateChanges.listen(
        (user) {
          if (user != null) {
            state = AuthState.authenticated(user);
          } else {
            state = const AuthState.unauthenticated();
          }
        },
      );
    } catch (error) {
      state = AuthState.error(
        'Failed to restore authentication session.',
      );
    }
  }

  Future<void> signIn(
    String email,
    String password,
  ) async {
    try {
      state = const AuthState.authenticating();

      final result = await _repository.signInWithEmail(
        email,
        password,
      );

      switch (result.status) {
        case AuthResultStatus.authenticated:
          final user = result.user;

          if (user == null) {
            throw StateError(
              'Authenticated result does not contain a user.',
            );
          }

          state = AuthState.authenticated(user);
          break;

        case AuthResultStatus.confirmationRequired:
          state =
              const AuthState.emailConfirmationRequired();
          break;
      }
    } catch (error) {
      state = AuthState.error(
        _mapAuthError(error),
      );
    }
  }

  Future<void> signUp(
    String email,
    String password,
  ) async {
    try {
      state = const AuthState.authenticating();

      final result = await _repository.signUpWithEmail(
        email,
        password,
      );

      switch (result.status) {
        case AuthResultStatus.authenticated:
          final user = result.user;

          if (user == null) {
            throw StateError(
              'Authenticated result does not contain a user.',
            );
          }

          state = AuthState.authenticated(user);
          break;

        case AuthResultStatus.confirmationRequired:
          state =
              const AuthState.emailConfirmationRequired();
          break;
      }
    } catch (error) {
      state = AuthState.error(
        _mapAuthError(error),
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _repository.signOut();

      state = const AuthState.unauthenticated();
    } catch (error) {
      state = AuthState.error(
        _mapAuthError(error),
      );
    }
  }

  String _mapAuthError(Object error) {
    return error.toString();
  }

  void clearEmailConfirmation() {
    state = const AuthState.unauthenticated();
  }
}