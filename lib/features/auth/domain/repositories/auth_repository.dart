import 'dart:typed_data';

import '../models/app_user.dart';
import '../models/auth_result.dart';

enum AuthEvent { signedIn, signedOut, passwordRecovery }

class AuthStateChange {
  final AuthEvent event;
  final AppUser? user;

  const AuthStateChange({required this.event, this.user});
}

abstract interface class AuthRepository {
  Future<AppUser?> getCurrentUser();

  Future<AuthResult> signInWithEmail(String email, String password);

  Future<AuthResult> signUpWithEmail(String email, String password);

  Future<void> signInWithGoogle();

  Future<void> sendPasswordReset(String email);

  Future<void> updatePassword(String password);

  Future<AppUser> updateProfile({
    required String displayName,
    Uint8List? avatarBytes,
    String? avatarContentType,
  });

  Future<void> signOut();

  Stream<AuthStateChange> get authStateChanges;
}
