import '../models/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile?> getProfile(String userId);

  Future<List<UserProfile>> getProfiles(Iterable<String> userIds);

  Stream<UserProfile> watchProfileChanges();
}
