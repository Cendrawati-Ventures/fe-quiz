class StudentAccount {
  const StudentAccount({
    required this.id,
    required this.username,
    required this.role,
  });

  final String id;
  final String username;
  final String role;

  factory StudentAccount.fromJson(Map<String, dynamic> json) {
    return StudentAccount(
      id: json["id"] as String,
      username: json["username"] as String,
      role: json["role"] as String? ?? "siswa",
    );
  }
}
