class AppUser {
  final String id;
  final String? email;
  final String? name;
  final String? avatarUrl;

  const AppUser({
    required this.id,
    this.email,
    this.name,
    this.avatarUrl,
  });
}