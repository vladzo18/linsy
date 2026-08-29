import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  // Проверь только эту строку.
  //
  // Если твой текущий Storage bucket
  // называется не "avatars", поставь здесь
  // его настоящее имя.
  static const String _avatarBucket = 'avatars';

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
    final ids = userIds.where((id) => id.isNotEmpty).toSet().toList();

    if (ids.isEmpty) {
      return const [];
    }

    final rows = await _client.from('profiles').select().inFilter('id', ids);

    return rows
        .map((row) => _mapProfile(Map<String, dynamic>.from(row)))
        .toList();
  }

  // ===================================================
  // UPDATE
  // ===================================================

  @override
  Future<UserProfile> updateProfile({
    required String userId,
    required String displayName,
    Uint8List? avatarBytes,
    String? avatarContentType,
  }) async {
    final normalizedName = displayName.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError('Display name cannot be empty.');
    }

    if (normalizedName.length > 40) {
      throw ArgumentError('Display name cannot exceed 40 characters.');
    }

    final currentUserId = _client.auth.currentUser?.id;

    if (currentUserId == null) {
      throw StateError('Cannot update profile while signed out.');
    }

    if (currentUserId != userId) {
      throw StateError('Cannot update another user profile.');
    }

    String? avatarUrl;

    // =================================================
    // NEW AVATAR
    // =================================================
    //
    // Каждый новый avatar получает НОВЫЙ path.
    //
    // Поэтому NetworkImage никогда не использует
    // старые bytes по тому же URL.
    // =================================================

    if (avatarBytes != null) {
      final contentType = avatarContentType ?? 'image/jpeg';

      final extension = _extensionForContentType(contentType);

      final version = DateTime.now().toUtc().microsecondsSinceEpoch;

      final path = '$userId/$version.$extension';

      await _client.storage
          .from(_avatarBucket)
          .uploadBinary(
            path,
            avatarBytes,
            fileOptions: FileOptions(upsert: false, contentType: contentType),
          );

      avatarUrl = _client.storage.from(_avatarBucket).getPublicUrl(path);
    }

    // =================================================
    // DATABASE
    // =================================================

    final values = <String, dynamic>{'display_name': normalizedName};

    if (avatarUrl != null) {
      values['avatar_url'] = avatarUrl;
    }

    final row = await _client
        .from('profiles')
        .update(values)
        .eq('id', userId)
        .select()
        .single();

    return _mapProfile(Map<String, dynamic>.from(row));
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

    final rawName = data['display_name'];

    final rawAvatar = data['avatar_url'];

    return UserProfile(
      id: data['id'] as String,
      displayName: rawName is String ? rawName.trim() : null,
      avatarUrl: rawAvatar is String && rawAvatar.trim().isNotEmpty
          ? rawAvatar.trim()
          : null,
      updatedAt: rawUpdatedAt is String
          ? DateTime.tryParse(rawUpdatedAt)?.toUtc()
          : null,
    );
  }

  // ===================================================
  // AVATAR EXTENSION
  // ===================================================

  String _extensionForContentType(String contentType) {
    switch (contentType.toLowerCase()) {
      case 'image/png':
        return 'png';

      case 'image/webp':
        return 'webp';

      case 'image/gif':
        return 'gif';

      case 'image/jpeg':
      case 'image/jpg':
      default:
        return 'jpg';
    }
  }
}
