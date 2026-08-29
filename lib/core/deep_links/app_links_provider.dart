import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/core/platform/deep_links/app_links_service.dart';

final appLinksServiceProvider = Provider<AppLinksService>((ref) {
  final service = SupabaseAppLinksService();

  ref.onDispose(service.dispose);

  return service;
});