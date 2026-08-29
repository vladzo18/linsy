import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/auth_repository_provider.dart';
import '../../domain/errors/auth_error_mapper.dart';
import '../../domain/models/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repository;

  StreamSubscription<AuthStateChange>? _authSubscription;

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
        (change) {
          switch (change.event) {
            case AuthEvent.signedIn:
              final user = change.user;

              if (user != null) {
                state = AuthState.authenticated(user);
              }

              break;

            case AuthEvent.signedOut:
              state = const AuthState.unauthenticated();

              break;

            case AuthEvent.passwordRecovery:
              final user = change.user;

              if (user != null) {
                state = AuthState.passwordRecovery(user);
              }

              break;
          }
        },
        onError: (error, stackTrace) {
          state = AuthState.error(AuthErrorMapper.map(error));
        },
      );
    } catch (error) {
      state = AuthState.error(AuthErrorMapper.map(error));
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      state = const AuthState.authenticating();

      final result = await _repository.signInWithEmail(email, password);

      switch (result.status) {
        case AuthResultStatus.authenticated:
          final user = result.user;

          if (user == null) {
            throw StateError('Authenticated result does not contain a user.');
          }

          state = AuthState.authenticated(user);

          break;

        case AuthResultStatus.confirmationRequired:
          state = const AuthState.emailConfirmationRequired();

          break;
      }
    } catch (error) {
      state = AuthState.error(AuthErrorMapper.map(error));
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      state = const AuthState.authenticating();

      final result = await _repository.signUpWithEmail(email, password);

      switch (result.status) {
        case AuthResultStatus.authenticated:
          final user = result.user;

          if (user == null) {
            throw StateError('Authenticated result does not contain a user.');
          }

          state = AuthState.authenticated(user);

          break;

        case AuthResultStatus.confirmationRequired:
          state = const AuthState.emailConfirmationRequired();

          break;
      }
    } catch (error) {
      state = AuthState.error(AuthErrorMapper.map(error));
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      state = const AuthState.authenticating();

      await _repository.signInWithGoogle();

      // Supabase authStateChanges является
      // источником истины для новой session.
    } catch (error) {
      state = AuthState.error(AuthErrorMapper.map(error));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      state = const AuthState.authenticating();

      await _repository.sendPasswordReset(email);

      state = const AuthState.passwordResetRequested();
    } catch (error) {
      state = AuthState.error(AuthErrorMapper.map(error));
    }
  }

  Future<void> updatePassword(String password) async {
    try {
      state = const AuthState.authenticating();

      await _repository.updatePassword(password);

      final user = await _repository.getCurrentUser();

      if (user == null) {
        state = const AuthState.unauthenticated();

        return;
      }

      state = AuthState.authenticated(user);
    } catch (error) {
      state = AuthState.error(AuthErrorMapper.map(error));
    }
  }

  Future<void> signOut() async {
    try {
      await _repository.signOut();

      state = const AuthState.unauthenticated();
    } catch (error) {
      state = AuthState.error(AuthErrorMapper.map(error));
    }
  }

  void clearAuthError() {
    if (state.status == AuthStatus.error) {
      state = const AuthState.unauthenticated();
    }
  }

  void clearEmailConfirmation() {
    if (state.status == AuthStatus.emailConfirmationRequired) {
      state = const AuthState.unauthenticated();
    }
  }
}
