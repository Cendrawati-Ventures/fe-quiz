enum UserRole { admin, siswa }

UserRole userRoleFromString(String value) {
  switch (value) {
    case 'admin':
      return UserRole.admin;
    case 'siswa':
      return UserRole.siswa;
    default:
      return UserRole.siswa;
  }
}

String userRoleToString(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'admin';
    case UserRole.siswa:
      return 'siswa';
  }
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.role,
  });

  final String id;
  final String username;
  final UserRole role;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      username: json['username'] as String,
      role: userRoleFromString(json['role'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'username': username,
      'role': userRoleToString(role),
    };
  }
}
