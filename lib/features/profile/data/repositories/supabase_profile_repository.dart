import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  // ===================================================
  // GET ONE
  // ===================================================

  @override
  Future<UserProfile?> getProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return _mapProfile(Map<String, dynamic>.from(row));
  }

  // ===================================================
  // GET MANY
  // ===================================================

  @override
  Future<List<UserProfile>> getProfiles(Iterable<String> userIds) async {
    final ids = userIds.toSet().toList();

    if (ids.isEmpty) {
      return const [];
    }

    final rows = await _client.from('profiles').select().inFilter('id', ids);

    return rows
        .map((row) => _mapProfile(Map<String, dynamic>.from(row)))
        .toList();
  }

  // ===================================================
  // REALTIME
  // ===================================================

  @override
  Stream<UserProfile> watchProfileChanges() {
    final controller = StreamController<UserProfile>.broadcast(sync: true);

    RealtimeChannel? channel;

    channel = _client
        .channel(
          'global-profile-store-'
          '${DateTime.now().microsecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            final data = payload.newRecord;

            if (data.isEmpty) {
              return;
            }

            final id = data['id'];

            if (id is! String) {
              return;
            }

            if (!controller.isClosed) {
              controller.add(_mapProfile(data));
            }
          },
        )
        .subscribe();

    controller.onCancel = () async {
      final currentChannel = channel;

      channel = null;

      if (currentChannel != null) {
        await _client.removeChannel(currentChannel);
      }

      if (!controller.isClosed) {
        await controller.close();
      }
    };

    return controller.stream;
  }

  // ===================================================
  // MAP
  // ===================================================

  UserProfile _mapProfile(Map<String, dynamic> data) {
    final rawUpdatedAt = data['updated_at'];

    return UserProfile(
      id: data['id'] as String,

      displayName: data['display_name'] as String?,

      avatarUrl: data['avatar_url'] as String?,

      updatedAt: rawUpdatedAt is String
          ? DateTime.tryParse(rawUpdatedAt)
          : null,
    );
  }
}
