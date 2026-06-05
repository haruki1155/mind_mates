class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    this.name,
  });

  final String id;
  final String email;
  final String? name;
}
