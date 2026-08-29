import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/app_user.dart';
import '../../domain/models/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';
import 'dart:typed_data';

class SupabaseAuthRepository implements AuthRepository {
  static const _googleWebClientId =
      '859536519885-0mcg2jsdkajosma61ojh8a1sg528ae5s.apps.googleusercontent.com';

  static const _googleAndroidClientId =
      '859536519885-igeik56j9r5e8vonisaa9h5a8ok37rle.apps.googleusercontent.com';

  final SupabaseClient _client;

  Future<void>? _googleInitialization;

  SupabaseAuthRepository(this._client);

  @override
  Future<AppUser?> getCurrentUser() async {
    final user = _client.auth.currentUser;

    return user == null ? null : _mapUser(user);
  }

  @override
  Future<AuthResult> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    final session = response.session;

    if (user == null || session == null) {
      throw StateError('Sign in succeeded without creating a session.');
    }

    return AuthResult(
      status: AuthResultStatus.authenticated,
      user: _mapUser(user),
    );
  }

  @override
  Future<AuthResult> signUpWithEmail(String email, String password) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'linsy://auth/confirmed',
    );

    final user = response.user;
    final session = response.session;

    if (user == null) {
      throw StateError('Supabase did not return a user after sign up.');
    }

    if (session == null) {
      return const AuthResult(status: AuthResultStatus.confirmationRequired);
    }

    return AuthResult(
      status: AuthResultStatus.authenticated,
      user: _mapUser(user),
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      await _signInWithGoogleOAuth();
      return;
    }

    await _signInWithGoogleNative();
  }

  Future<void> _signInWithGoogleNative() async {
    await _initializeGoogleSignIn();

    final googleSignIn = GoogleSignIn.instance;

    if (!googleSignIn.supportsAuthenticate()) {
      throw StateError('Google Sign-In is not supported on this platform.');
    }

    final googleUser = await googleSignIn.authenticate();

    final googleAuthentication = googleUser.authentication;

    final idToken = googleAuthentication.idToken;

    if (idToken == null) {
      throw StateError('Google did not return an ID token.');
    }

    final authorization = await googleUser.authorizationClient
        .authorizationForScopes(const <String>['email', 'profile']);

    final accessToken = authorization?.accessToken;

    if (accessToken == null) {
      throw StateError('Google did not return an access token.');
    }

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> _initializeGoogleSignIn() {
    return _googleInitialization ??= _initializeGoogleSignInInternal();
  }

  Future<void> _initializeGoogleSignInInternal() async {
    String? clientId;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        clientId = _googleAndroidClientId;
        break;

      case TargetPlatform.iOS:
        // We will replace this with the iOS OAuth Client ID
        // when the iOS configuration is added.
        clientId = null;
        break;

      default:
        clientId = null;
    }

    await GoogleSignIn.instance.initialize(
      clientId: clientId,
      serverClientId: _googleWebClientId,
    );
  }

  Future<void> _signInWithGoogleOAuth() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'linsy://auth/google',
    );
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'linsy://auth/reset-password',
    );
  }

  @override
  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  // =====================================================================
  // PROFILE
  // =====================================================================

  @override
  Future<AppUser> updateProfile({
    required String displayName,
    Uint8List? avatarBytes,
    String? avatarContentType,
  }) async {
    final currentUser = _client.auth.currentUser;

    if (currentUser == null) {
      throw StateError('Cannot update profile while signed out.');
    }

    final cleanedName = displayName.trim();

    if (cleanedName.isEmpty) {
      throw ArgumentError('Display name cannot be empty.');
    }

    if (cleanedName.length > 40) {
      throw ArgumentError('Display name is too long.');
    }

    String? avatarUrl = currentUser.userMetadata?['avatar_url'] as String?;

    // ===============================================================
    // AVATAR
    // ===============================================================

    if (avatarBytes != null) {
      const maxAvatarSize = 5 * 1024 * 1024;

      if (avatarBytes.lengthInBytes > maxAvatarSize) {
        throw ArgumentError('Avatar must be smaller than 5 MB.');
      }

      final path = '${currentUser.id}/avatar';

      await _client.storage
          .from('avatars')
          .uploadBinary(
            path,
            avatarBytes,
            fileOptions: FileOptions(
              upsert: true,
              cacheControl: '3600',
              contentType: avatarContentType ?? 'image/jpeg',
            ),
          );

      final publicUrl = _client.storage.from('avatars').getPublicUrl(path);

      // Cache busting.
      avatarUrl =
          '$publicUrl?v='
          '${DateTime.now().millisecondsSinceEpoch}';
    }

    // ===============================================================
    // UPDATE PUBLIC PROFILE
    // ===============================================================

    await _client
        .from('profiles')
        .update({'display_name': cleanedName, 'avatar_url': avatarUrl})
        .eq('id', currentUser.id)
        .select()
        .single();
    // ===============================================================
    // AUTH METADATA
    // ===============================================================

    final response = await _client.auth.updateUser(
      UserAttributes(
        data: {
          'display_name': cleanedName,

          if (avatarUrl != null) 'avatar_url': avatarUrl,
        },
      ),
    );

    final updatedUser = response.user;

    if (updatedUser == null) {
      throw StateError('Supabase did not return the updated user.');
    }

    return _mapUser(updatedUser);
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }

  @override
  Stream<AuthStateChange> get authStateChanges {
    return _client.auth.onAuthStateChange.map((data) {
      final user = data.session?.user;
      final appUser = user == null ? null : _mapUser(user);

      switch (data.event) {
        case AuthChangeEvent.signedIn:
          return AuthStateChange(event: AuthEvent.signedIn, user: appUser);

        case AuthChangeEvent.signedOut:
          return const AuthStateChange(event: AuthEvent.signedOut);

        case AuthChangeEvent.passwordRecovery:
          return AuthStateChange(
            event: AuthEvent.passwordRecovery,
            user: appUser,
          );

        default:
          return AuthStateChange(event: AuthEvent.signedIn, user: appUser);
      }
    });
  }

  AppUser _mapUser(User user) {
    final metadata = user.userMetadata;

    final displayName = metadata?['display_name'] as String?;

    final fullName = metadata?['full_name'] as String?;

    final googleName = metadata?['name'] as String?;

    final avatarUrl = metadata?['avatar_url'] as String?;

    final picture = metadata?['picture'] as String?;

    return AppUser(
      id: user.id,
      email: user.email,
      name: displayName ?? fullName ?? googleName,
      avatarUrl: avatarUrl ?? picture,
    );
  }
}
