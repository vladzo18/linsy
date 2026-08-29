import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AppLinksService {
  Future<void> initialize();

  Future<void> dispose();
}

class SupabaseAppLinksService implements AppLinksService {
  final AppLinks _appLinks;
  final SupabaseClient _supabase;

  StreamSubscription<Uri>? _subscription;

  SupabaseAppLinksService({
    AppLinks? appLinks,
    SupabaseClient? supabase,
  }) : _appLinks = appLinks ?? AppLinks(),
       _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<void> initialize() async {
    _subscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Deep link error: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );

    final initialUri = await _appLinks.getInitialLink();

    if (initialUri != null) {
      await _handleUri(initialUri);
    }
  }

  Future<void> _handleUri(Uri uri) async {
    debugPrint('Incoming deep link: $uri');

    if (uri.scheme != 'linsy') {
      return;
    }

    try {
      await _supabase.auth.getSessionFromUrl(uri);
    } catch (error, stackTrace) {
      debugPrint('Supabase deep link error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}