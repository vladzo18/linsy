import '../../domain/models/app_user.dart';

enum AuthStatus {
  initializing,
  unauthenticated,
  authenticating,
  authenticated,
  emailConfirmationRequired,
  error,
}

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  const AuthState.initializing()
      : status = AuthStatus.initializing,
        user = null,
        errorMessage = null;

  const AuthState.unauthenticated()
      : status = AuthStatus.unauthenticated,
        user = null,
        errorMessage = null;

  const AuthState.authenticating()
      : status = AuthStatus.authenticating,
        user = null,
        errorMessage = null;

  const AuthState.authenticated(AppUser this.user)
      : status = AuthStatus.authenticated,
        errorMessage = null;

  const AuthState.emailConfirmationRequired()
      : status = AuthStatus.emailConfirmationRequired,
        user = null,
        errorMessage = null;

  const AuthState.error(String message)
      : status = AuthStatus.error,
        user = null,
        errorMessage = message;
}