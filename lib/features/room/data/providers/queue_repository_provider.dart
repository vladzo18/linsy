import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linsy/features/room/domain/repositories/supabase_queue_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/queue_repository.dart';

final queueRepositoryProvider =
    Provider<QueueRepository>((ref) {
  return SupabaseQueueRepository(
    Supabase.instance.client,
  );
});