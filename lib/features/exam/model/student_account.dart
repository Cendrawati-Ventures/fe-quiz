class StudentAccount {
  const StudentAccount({
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
  final String role;

  factory StudentAccount.fromJson(Map<String, dynamic> json) {
    return StudentAccount(
      id: json["id"] as String,
      username: json["username"] as String,
      displayName: json["displayName"] as String?,
      fullName: json["fullName"] as String?,
      classId: json["classId"] as String?,
      className: json["className"] as String?,
      rollNumber: json["rollNumber"] as String?,
      role: json["role"] as String? ?? "siswa",
    );
  }
}
