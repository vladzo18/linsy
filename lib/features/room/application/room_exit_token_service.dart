import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final roomExitTokenServiceProvider = Provider<RoomExitTokenService>((ref) {
  return RoomExitTokenService(Supabase.instance.client);
});

class RoomExitTokenService {
  RoomExitTokenService(this._client);

  final SupabaseClient _client;

  Future<String> issue({required String roomId}) async {
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

    return cleanupToken;
  }
}
