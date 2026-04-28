class AdminClassSummary {
  const AdminClassSummary({
    required this.id,
    required this.name,
    required this.studentCount,
    required this.subjectCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int studentCount;
  final int subjectCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AdminClassSummary.fromJson(Map<String, dynamic> json) {
    return AdminClassSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      studentCount: (json['studentCount'] as num? ?? 0).toInt(),
      subjectCount: (json['subjectCount'] as num? ?? 0).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class AdminClassDetail {
  const AdminClassDetail({
    required this.id,
    required this.name,
    required this.studentIds,
    required this.subjectIds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> studentIds;
  final List<String> subjectIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AdminClassDetail.fromJson(Map<String, dynamic> json) {
    return AdminClassDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      studentIds: (json['studentIds'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
      subjectIds: (json['subjectIds'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class StudentClassOption {
  const StudentClassOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory StudentClassOption.fromJson(Map<String, dynamic> json) {
    return StudentClassOption(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}
