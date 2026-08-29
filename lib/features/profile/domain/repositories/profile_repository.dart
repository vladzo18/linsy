import 'dart:typed_data';

import '../models/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile?> getProfile(String userId);

  Future<List<UserProfile>> getProfiles(Iterable<String> userIds);

  Future<UserProfile> updateProfile({
    required String userId,
    required String displayName,
    Uint8List? avatarBytes,
    String? avatarContentType,
  });

  Stream<UserProfile> watchProfileChanges();
}
