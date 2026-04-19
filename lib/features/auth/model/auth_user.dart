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
    required this.displayName,
    required this.fullName,
    required this.classId,
    required this.className,
    required this.rollNumber,
    required this.role,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? fullName;
  final String? classId;
  final String? className;
  final String? rollNumber;
  final UserRole role;

  String get effectiveDisplayName {
    final value = displayName?.trim();
    if (value == null || value.isEmpty) {
      return username;
    }
    return value;
  }

  bool get hasCompleteStudentIdentity {
    final fullNameValue = fullName?.trim() ?? '';
    final classNameValue = className?.trim() ?? '';
    final rollNumberValue = rollNumber?.trim() ?? '';
    return fullNameValue.isNotEmpty &&
        classNameValue.isNotEmpty &&
        rollNumberValue.isNotEmpty;
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String?,
      fullName: json['fullName'] as String?,
      classId: json['classId'] as String?,
      className: json['className'] as String?,
      rollNumber: json['rollNumber'] as String?,
      role: userRoleFromString(json['role'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'username': username,
      'displayName': displayName,
      'fullName': fullName,
      'classId': classId,
      'className': className,
      'rollNumber': rollNumber,
      'role': userRoleToString(role),
    };
  }
}
