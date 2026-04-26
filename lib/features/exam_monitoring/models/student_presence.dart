import 'package:firebase_database/firebase_database.dart';

import 'exam_student_status.dart';

class StudentPresence {
  const StudentPresence({
    required this.name,
    required this.status,
    required this.violations,
    required this.device,
    required this.connection,
    this.lastSeenEpochMs,
  });

  final String name;
  final ExamStudentStatus status;
  final int violations;
  final String device;
  final bool connection;
  final int? lastSeenEpochMs;

  Map<String, dynamic> toMap({
    bool useServerTimestamp = true,
  }) {
    return <String, dynamic>{
      'name': name,
      'status': status.value,
      'lastSeen': useServerTimestamp
          ? ServerValue.timestamp
          : (lastSeenEpochMs ?? DateTime.now().toUtc().millisecondsSinceEpoch),
      'violations': violations,
      'device': device,
      'connection': connection,
    };
  }

  factory StudentPresence.fromMap(Map<Object?, Object?> raw) {
    return StudentPresence(
      name: (raw['name'] ?? '').toString(),
      status: ExamStudentStatus.fromValue(raw['status']?.toString()),
      lastSeenEpochMs: (raw['lastSeen'] as num?)?.toInt(),
      violations: (raw['violations'] as num?)?.toInt() ?? 0,
      device: (raw['device'] ?? '').toString(),
      connection: raw['connection'] == true,
    );
  }
}
