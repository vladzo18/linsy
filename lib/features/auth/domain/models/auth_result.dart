import 'app_user.dart';

enum AuthResultStatus {
  authenticated,
  confirmationRequired,
}

class AuthResult {
  final AuthResultStatus status;
  final AppUser? user;

  const AuthResult({
    required this.status,
    this.user,
  });
}