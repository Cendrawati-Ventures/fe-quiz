class StudentExamSessionConfig {
  const StudentExamSessionConfig({
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.agoraAppId,
    required this.agoraChannel,
    required this.agoraUid,
    this.agoraToken,
    this.firebaseDatabaseUrl,
    this.device,
    this.initialViolations = 0,
  });

  final String sessionId;
  final String studentId;
  final String studentName;
  final String agoraAppId;
  final String agoraChannel;
  final int agoraUid;
  final String? agoraToken;
  final String? firebaseDatabaseUrl;
  final String? device;
  final int initialViolations;
}
