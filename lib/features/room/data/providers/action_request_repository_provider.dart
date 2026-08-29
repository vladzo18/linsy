import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/room/domain/repositories/supabase_action_request_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/action_request_repository.dart';

final actionRequestRepositoryProvider = Provider<ActionRequestRepository>((
  ref,
) {
  return SupabaseActionRequestRepository(Supabase.instance.client);
});
