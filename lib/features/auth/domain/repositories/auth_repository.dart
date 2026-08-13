import 'package:linsy/features/auth/domain/models/app_user.dart';
import 'package:linsy/features/auth/domain/models/auth_result.dart';

abstract interface class AuthRepository {
  Future<AppUser?> getCurrentUser();

  Future<AuthResult> signInWithEmail(
    String email,
    String password,
  );

  Future<AuthResult> signUpWithEmail(
    String email,
    String password,
  );

  Future<void> signOut();

  Stream<AppUser?> get authStateChanges;
}