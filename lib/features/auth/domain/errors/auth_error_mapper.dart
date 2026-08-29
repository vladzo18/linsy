import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class AuthErrorMapper {
  static String map(Object error) {
    if (error is AuthException) {
      return _mapAuthException(error);
    }

    return 'Something went wrong. Please try again.';
  }

  static String _mapAuthException(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('invalid login credentials')) {
      return 'Invalid email or password.';
    }

    if (message.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }

    if (message.contains('user already registered')) {
      return 'An account with this email already exists.';
    }

    if (message.contains('password should be at least')) {
      return 'Your password is too short.';
    }

    if (message.contains('email address') &&
        message.contains('invalid')) {
      return 'Please enter a valid email address.';
    }

    if (message.contains('rate limit')) {
      return 'Too many requests. Please try again later.';
    }

    return 'Authentication failed. Please try again.';
  }
}