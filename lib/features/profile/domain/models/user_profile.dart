class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    required this.updatedAt,
  });

  final String id;

  final String? displayName;

  final String? avatarUrl;

  final DateTime? updatedAt;

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is UserProfile &&
        other.id == id &&
        other.displayName == displayName &&
        other.avatarUrl == avatarUrl &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, displayName, avatarUrl, updatedAt);
  }
}
