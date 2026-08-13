import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/app_user.dart';
import '../../domain/models/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  @override
  Future<AppUser?> getCurrentUser() async {
    final user = _client.auth.currentUser;

    return user == null ? null : _mapUser(user);
  }

  @override
  Future<AuthResult> signInWithEmail(
    String email,
    String password,
  ) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    final session = response.session;

    if (user == null || session == null) {
      throw StateError(
        'Sign in succeeded without creating a session.',
      );
    }

    return AuthResult(
      status: AuthResultStatus.authenticated,
      user: _mapUser(user),
    );
  }

  @override
Future<AuthResult> signUpWithEmail(
  String email,
  String password,
) async {

  final response = await _client.auth.signUp(
    email: email,
    password: password,
    emailRedirectTo: 'linsy://auth/confirmed',
  );

  final user = response.user;
  final session = response.session;

  if (user == null) {
    throw StateError(
      'Supabase did not return a user after sign up.',
    );
  }

  if (session == null) {
    return const AuthResult(
      status: AuthResultStatus.confirmationRequired,
    );
  }

  return AuthResult(
    status: AuthResultStatus.authenticated,
    user: _mapUser(user),
  );
}

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }

  @override
  Stream<AppUser?> get authStateChanges {
    return _client.auth.onAuthStateChange.map(
      (data) {
        final user = data.session?.user;

        return user == null ? null : _mapUser(user);
      },
    );
  }

  AppUser _mapUser(User user) {
    final metadata = user.userMetadata;

    return AppUser(
      id: user.id,
      email: user.email,
      name: metadata?['display_name'] as String?,
      avatarUrl: metadata?['avatar_url'] as String?,
    );
  }
}