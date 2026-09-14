import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final roomExitTokenServiceProvider = Provider<RoomExitTokenService>((ref) {
  return RoomExitTokenService(Supabase.instance.client);
});

class RoomExitTokenService {
  RoomExitTokenService(this._client);

  final SupabaseClient _client;
  String? _roomId;
  String? _token;
  int _generation = 0;

  Future<String> issue({required String roomId}) async {
    final generation = ++_generation;
    final response = await _client.functions.invoke(
      'room-exit-register',
      body: {'roomId': roomId},
    );

    final rawData = response.data;

    if (rawData is! Map) {
      throw StateError('Invalid room exit response.');
    }

    final data = Map<String, dynamic>.from(rawData);

    final cleanupToken = data['cleanupToken'];

    if (cleanupToken is! String || cleanupToken.isEmpty) {
      throw StateError('Room exit token was not returned.');
    }

    if (generation == _generation) {
      _roomId = roomId;
      _token = cleanupToken;
    }
    return cleanupToken;
  }

  Future<bool?> renew({required String roomId}) async {
    final token = _token;
    if (_roomId != roomId || token == null) return null;
    final response = await _client.functions.invoke(
      'room-exit-heartbeat',
      body: {'cleanupToken': token},
    );
    if (_token != token || _roomId != roomId) return null;
    final data = response.data;
    if (data is! Map || data['active'] is! bool) {
      throw StateError('Invalid heartbeat response.');
    }
    return data['active'] as bool;
  }

  void clear({required String roomId}) {
    if (_roomId != roomId) return;
    ++_generation;
    _roomId = null;
    _token = null;
  }
}
