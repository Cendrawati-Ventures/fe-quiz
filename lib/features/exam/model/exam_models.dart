import '../../auth/model/auth_user.dart';

num _readNum(dynamic value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value) ?? 0;
  }
  return 0;
}

enum QuestionType { single, multi, group }

QuestionType questionTypeFromString(String value) {
  switch (value) {
    case 'single':
      return QuestionType.single;
    case 'multi':
      return QuestionType.multi;
    case 'group':
      return QuestionType.group;
    default:
      return QuestionType.single;
  }
}

String questionTypeToString(QuestionType value) {
  switch (value) {
    case QuestionType.single:
      return 'single';
    case QuestionType.multi:
      return 'multi';
    case QuestionType.group:
      return 'group';
  }
}

enum AttemptStatus { inProgress, submitted, expired }

AttemptStatus attemptStatusFromString(String value) {
  switch (value) {
    case 'in_progress':
      return AttemptStatus.inProgress;
    case 'submitted':
      return AttemptStatus.submitted;
    case 'expired':
      return AttemptStatus.expired;
    default:
      return AttemptStatus.inProgress;
  }
}

String attemptStatusToString(AttemptStatus value) {
  switch (value) {
    case AttemptStatus.inProgress:
      return 'in_progress';
    case AttemptStatus.submitted:
      return 'submitted';
    case AttemptStatus.expired:
      return 'expired';
  }
}

enum RiskLevel { safe, suspicious, highRisk }

RiskLevel riskLevelFromString(String value) {
  switch (value) {
    case 'safe':
      return RiskLevel.safe;
    case 'suspicious':
      return RiskLevel.suspicious;
    case 'high_risk':
      return RiskLevel.highRisk;
    default:
      return RiskLevel.safe;
  }
}

String riskLevelToString(RiskLevel value) {
  switch (value) {
    case RiskLevel.safe:
      return 'safe';
    case RiskLevel.suspicious:
      return 'suspicious';
    case RiskLevel.highRisk:
      return 'high_risk';
  }
}

String riskLevelLabel(RiskLevel value) {
  switch (value) {
    case RiskLevel.safe:
      return 'Aman';
    case RiskLevel.suspicious:
      return 'Perlu Perhatian';
    case RiskLevel.highRisk:
      return 'Risiko Tinggi';
  }
}

enum ProctoringEventType { tabSwitch, appBackground, idle, noise }

ProctoringEventType proctoringEventTypeFromString(String value) {
  switch (value) {
    case 'tab_switch':
      return ProctoringEventType.tabSwitch;
    case 'app_background':
      return ProctoringEventType.appBackground;
    case 'idle':
      return ProctoringEventType.idle;
    case 'noise':
      return ProctoringEventType.noise;
    default:
      return ProctoringEventType.noise;
  }
}

String proctoringEventTypeToString(ProctoringEventType value) {
  switch (value) {
    case ProctoringEventType.tabSwitch:
      return 'tab_switch';
    case ProctoringEventType.appBackground:
      return 'app_background';
    case ProctoringEventType.idle:
      return 'idle';
    case ProctoringEventType.noise:
      return 'noise';
  }
}

class ApiExam {
  const ApiExam({
    required this.id,
    required this.title,
    required this.isPublished,
    required this.startTime,
    required this.endTime,
    this.videoProvider,
    this.videoRoomId,
  });

  final String id;
  final String title;
  final bool isPublished;
  final DateTime startTime;
  final DateTime endTime;
  final String? videoProvider;
  final String? videoRoomId;

  factory ApiExam.fromJson(Map<String, dynamic> json) {
    return ApiExam(
      id: json['id'] as String,
      title: json['title'] as String,
      isPublished: json['isPublished'] as bool? ?? false,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      videoProvider: json['videoProvider'] as String?,
      videoRoomId: json['videoRoomId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'isPublished': isPublished,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'videoProvider': videoProvider,
      'videoRoomId': videoRoomId,
    };
  }
}

class ApiSubject {
  const ApiSubject({
    required this.id,
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.attemptLimit,
    required this.allowReview,
    required this.publishAt,
    required this.closeAt,
  });

  final String id;
  final String name;
  final String description;
  final int durationMinutes;
  final int attemptLimit;
  final bool allowReview;
  final DateTime? publishAt;
  final DateTime? closeAt;

  factory ApiSubject.fromJson(Map<String, dynamic> json) {
    return ApiSubject(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      durationMinutes: json['durationMinutes'] as int,
      attemptLimit: json['attemptLimit'] as int,
      allowReview: json['allowReview'] as bool? ?? false,
      publishAt: (json['publishAt'] as String?) == null
          ? null
          : DateTime.parse(json['publishAt'] as String),
      closeAt: (json['closeAt'] as String?) == null
          ? null
          : DateTime.parse(json['closeAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'durationMinutes': durationMinutes,
      'attemptLimit': attemptLimit,
      'allowReview': allowReview,
      'publishAt': publishAt?.toIso8601String(),
      'closeAt': closeAt?.toIso8601String(),
    };
  }
}

class ApiQuestion {
  const ApiQuestion({
    required this.id,
    required this.subjectId,
    required this.type,
    required this.text,
    required this.options,
    required this.imageData,
    required this.weight,
  });

  final String id;
  final String subjectId;
  final QuestionType type;
  final String text;
  final Object? options;
  final String? imageData;
  final num weight;

  factory ApiQuestion.fromJson(Map<String, dynamic> json) {
    return ApiQuestion(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      type: questionTypeFromString(json['type'] as String),
      text: json['text'] as String,
      options: json['options'],
      imageData: json['imageData'] as String?,
      weight: _readNum(json['weight']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'subjectId': subjectId,
      'type': questionTypeToString(type),
      'text': text,
      'options': options,
      'imageData': imageData,
      'weight': weight,
    };
  }
}

class AdminQuestionOption {
  const AdminQuestionOption({
    required this.value,
    required this.label,
    this.imageData,
  });

  final String value;
  final String label;
  final String? imageData;

  factory AdminQuestionOption.fromJson(Map<String, dynamic> json) {
    return AdminQuestionOption(
      value: (json['value'] as String? ?? '').trim(),
      label: (json['label'] as String? ?? '').trim(),
      imageData: (json['imageData'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'value': value,
      'label': label,
      if (imageData != null && imageData!.isNotEmpty) 'imageData': imageData,
    };
  }
}

const List<String> adminDefaultOptionValues = <String>['A', 'B', 'C', 'D'];

const List<AdminQuestionOption> adminDefaultQuestionOptions =
    <AdminQuestionOption>[
  AdminQuestionOption(value: 'A', label: 'Opsi A'),
  AdminQuestionOption(value: 'B', label: 'Opsi B'),
  AdminQuestionOption(value: 'C', label: 'Opsi C'),
  AdminQuestionOption(value: 'D', label: 'Opsi D'),
];

String adminQuestionTypeLabel(QuestionType value) {
  switch (value) {
    case QuestionType.single:
      return 'PGS';
    case QuestionType.multi:
      return 'PGK-MCMA';
    case QuestionType.group:
      return 'PGK-Kategori';
  }
}

List<AdminQuestionOption> parseAdminChoiceOptions(Object? raw) {
  final result = <AdminQuestionOption>[];

  if (raw is List<dynamic>) {
    for (final item in raw) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final parsed = AdminQuestionOption.fromJson(item);
      if (parsed.value.isEmpty || parsed.label.isEmpty) {
        continue;
      }
      result.add(parsed);
    }
  } else if (raw is Map<String, dynamic>) {
    raw.forEach((key, value) {
      final optionValue = key.trim();
      final label = value is Map<String, dynamic>
          ? (value['label'] ?? value['text'])?.toString().trim() ?? ''
          : value?.toString().trim() ?? '';
      if (optionValue.isEmpty || label.isEmpty) {
        return;
      }
      result.add(
        AdminQuestionOption(
          value: optionValue,
          label: label,
          imageData: value is Map<String, dynamic>
              ? (value['imageData'] as String?)?.trim()
              : null,
        ),
      );
    });
  }

  if (result.isEmpty) {
    return List<AdminQuestionOption>.from(adminDefaultQuestionOptions);
  }

  return result;
}

List<String> parseAnswerValueList(Object? raw) {
  final values = <String>[];

  if (raw is String) {
    final value = raw.trim();
    if (value.isNotEmpty) {
      values.add(value);
    }
    return values;
  }

  if (raw is List<dynamic>) {
    for (final item in raw) {
      if (item is! String) {
        continue;
      }
      final value = item.trim();
      if (value.isEmpty || values.contains(value)) {
        continue;
      }
      values.add(value);
    }
  }

  return values;
}

class AdminQuestion {
  const AdminQuestion({
    required this.id,
    required this.subjectId,
    required this.type,
    required this.text,
    required this.options,
    required this.correctAnswer,
    required this.imageData,
    required this.weight,
    required this.orderIndex,
  });

  final String id;
  final String subjectId;
  final QuestionType type;
  final String text;
  final Object? options;
  final Object? correctAnswer;
  final String? imageData;
  final num weight;
  final int orderIndex;

  factory AdminQuestion.fromJson(Map<String, dynamic> json) {
    return AdminQuestion(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      type: questionTypeFromString(json['type'] as String? ?? 'single'),
      text: (json['text'] as String? ?? '').trim(),
      options: json['options'],
      correctAnswer: json['correctAnswer'],
      imageData: json['imageData'] as String?,
      weight: _readNum(json['weight']),
      orderIndex: _readNum(json['orderIndex']).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'subjectId': subjectId,
      'type': questionTypeToString(type),
      'text': text,
      'options': options,
      'correctAnswer': correctAnswer,
      'imageData': imageData,
      'weight': weight,
      'orderIndex': orderIndex,
    };
  }
}

class ApiAttempt {
  const ApiAttempt({
    required this.id,
    required this.userId,
    required this.examId,
    required this.subjectId,
    required this.attemptNo,
    required this.startTime,
    required this.status,
    this.endTime,
  });

  final String id;
  final String userId;
  final String examId;
  final String subjectId;
  final int attemptNo;
  final DateTime startTime;
  final DateTime? endTime;
  final AttemptStatus status;

  factory ApiAttempt.fromJson(Map<String, dynamic> json) {
    return ApiAttempt(
      id: json['id'] as String,
      userId: json['userId'] as String,
      examId: json['examId'] as String,
      subjectId: json['subjectId'] as String,
      attemptNo: json['attemptNo'] as int,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: (json['endTime'] as String?) == null
          ? null
          : DateTime.parse(json['endTime'] as String),
      status: attemptStatusFromString(json['status'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'examId': examId,
      'subjectId': subjectId,
      'attemptNo': attemptNo,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'status': attemptStatusToString(status),
    };
  }

  ApiAttempt copyWith({
    String? id,
    String? userId,
    String? examId,
    String? subjectId,
    int? attemptNo,
    DateTime? startTime,
    DateTime? endTime,
    AttemptStatus? status,
  }) {
    return ApiAttempt(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      examId: examId ?? this.examId,
      subjectId: subjectId ?? this.subjectId,
      attemptNo: attemptNo ?? this.attemptNo,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
    );
  }
}

class AttemptMonitoringConfig {
  const AttemptMonitoringConfig({
    required this.enabled,
    required this.provider,
    required this.reason,
    required this.agoraAppId,
    required this.agoraChannel,
    required this.agoraUid,
    required this.agoraPublisherUid,
    required this.agoraToken,
    required this.agoraTokenExpiresAt,
    required this.firebasePath,
    required this.firebaseDatabaseUrl,
    required this.firebaseProjectId,
  });

  final bool enabled;
  final String provider;
  final String? reason;
  final String? agoraAppId;
  final String? agoraChannel;
  final int? agoraUid;
  final int? agoraPublisherUid;
  final String? agoraToken;
  final DateTime? agoraTokenExpiresAt;
  final String? firebasePath;
  final String? firebaseDatabaseUrl;
  final String? firebaseProjectId;

  factory AttemptMonitoringConfig.fromJson(Map<String, dynamic> json) {
    return AttemptMonitoringConfig(
      enabled: json['enabled'] as bool? ?? false,
      provider: json['provider'] as String? ?? 'agora',
      reason: json['reason'] as String?,
      agoraAppId: json['agoraAppId'] as String?,
      agoraChannel: json['agoraChannel'] as String?,
      agoraUid: (json['agoraUid'] as num?)?.toInt(),
      agoraPublisherUid: (json['agoraPublisherUid'] as num?)?.toInt(),
      agoraToken: json['agoraToken'] as String?,
      agoraTokenExpiresAt: (json['agoraTokenExpiresAt'] as String?) == null
          ? null
          : DateTime.parse(json['agoraTokenExpiresAt'] as String),
      firebasePath: json['firebasePath'] as String?,
      firebaseDatabaseUrl: json['firebaseDatabaseUrl'] as String?,
      firebaseProjectId: json['firebaseProjectId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'provider': provider,
      'reason': reason,
      'agoraAppId': agoraAppId,
      'agoraChannel': agoraChannel,
      'agoraUid': agoraUid,
      'agoraPublisherUid': agoraPublisherUid,
      'agoraToken': agoraToken,
      'agoraTokenExpiresAt': agoraTokenExpiresAt?.toIso8601String(),
      'firebasePath': firebasePath,
      'firebaseDatabaseUrl': firebaseDatabaseUrl,
      'firebaseProjectId': firebaseProjectId,
    };
  }
}

class ProctoringStandbyStatus {
  const ProctoringStandbyStatus({
    required this.isActive,
    required this.confirmedByUserId,
    required this.confirmedAt,
    required this.updatedAt,
  });

  final bool isActive;
  final String? confirmedByUserId;
  final DateTime? confirmedAt;
  final DateTime? updatedAt;

  factory ProctoringStandbyStatus.fromJson(Map<String, dynamic> json) {
    return ProctoringStandbyStatus(
      isActive: json['isActive'] as bool? ?? false,
      confirmedByUserId: json['confirmedByUserId'] as String?,
      confirmedAt: (json['confirmedAt'] as String?) == null
          ? null
          : DateTime.parse(json['confirmedAt'] as String),
      updatedAt: (json['updatedAt'] as String?) == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class ActiveMonitoringStudent {
  const ActiveMonitoringStudent({
    required this.id,
    required this.username,
    required this.displayName,
    required this.fullName,
    required this.classId,
    required this.className,
    required this.rollNumber,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? fullName;
  final String? classId;
  final String? className;
  final String? rollNumber;

  factory ActiveMonitoringStudent.fromJson(Map<String, dynamic> json) {
    return ActiveMonitoringStudent(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String?,
      fullName: json['fullName'] as String?,
      classId: json['classId'] as String?,
      className: json['className'] as String?,
      rollNumber: json['rollNumber'] as String?,
    );
  }

  String get labelName {
    final fullNameValue = fullName?.trim();
    if (fullNameValue != null && fullNameValue.isNotEmpty) {
      return fullNameValue;
    }
    final displayNameValue = displayName?.trim();
    if (displayNameValue != null && displayNameValue.isNotEmpty) {
      return displayNameValue;
    }
    return username.trim().isNotEmpty ? username.trim() : 'Siswa';
  }
}

class ActiveMonitoringAttempt {
  const ActiveMonitoringAttempt({
    required this.attemptId,
    required this.startedAt,
    required this.remainingSeconds,
    required this.student,
    required this.examId,
    required this.examTitle,
    required this.subjectId,
    required this.subjectName,
    required this.monitoring,
  });

  final String attemptId;
  final DateTime startedAt;
  final int remainingSeconds;
  final ActiveMonitoringStudent student;
  final String examId;
  final String examTitle;
  final String subjectId;
  final String subjectName;
  final AttemptMonitoringConfig monitoring;

  factory ActiveMonitoringAttempt.fromJson(Map<String, dynamic> json) {
    final studentRaw =
        json['student'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final examRaw =
        json['exam'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final subjectRaw =
        json['subject'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final monitoringRaw = json['monitoring'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    return ActiveMonitoringAttempt(
      attemptId: json['attemptId'] as String? ?? '',
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      remainingSeconds: (json['remainingSeconds'] as num?)?.toInt() ?? 0,
      student: ActiveMonitoringStudent.fromJson(studentRaw),
      examId: examRaw['id'] as String? ?? '',
      examTitle: examRaw['title'] as String? ?? '',
      subjectId: subjectRaw['id'] as String? ?? '',
      subjectName: subjectRaw['name'] as String? ?? '',
      monitoring: AttemptMonitoringConfig.fromJson(monitoringRaw),
    );
  }
}

class StartAttemptResponse {
  const StartAttemptResponse({
    required this.attempt,
    required this.questions,
    this.monitoring,
    this.serverNow,
    this.remainingSeconds,
  });

  final ApiAttempt attempt;
  final List<ApiQuestion> questions;
  final AttemptMonitoringConfig? monitoring;
  final DateTime? serverNow;
  final int? remainingSeconds;

  factory StartAttemptResponse.fromJson(Map<String, dynamic> json) {
    final rawQuestions = (json['questions'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
    return StartAttemptResponse(
      attempt: ApiAttempt.fromJson(json['attempt'] as Map<String, dynamic>),
      questions: rawQuestions.map(ApiQuestion.fromJson).toList(),
      monitoring: (json['monitoring'] as Map<String, dynamic>?) == null
          ? null
          : AttemptMonitoringConfig.fromJson(
              json['monitoring'] as Map<String, dynamic>,
            ),
      serverNow: (json['serverNow'] as String?) == null
          ? null
          : DateTime.parse(json['serverNow'] as String),
      remainingSeconds: json['remainingSeconds'] as int?,
    );
  }
}

class SaveAnswerResponse {
  const SaveAnswerResponse({
    required this.id,
    required this.attemptId,
    required this.questionId,
    required this.answer,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String attemptId;
  final String questionId;
  final Object? answer;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SaveAnswerResponse.fromJson(Map<String, dynamic> json) {
    return SaveAnswerResponse(
      id: json['id'] as String,
      attemptId: json['attemptId'] as String,
      questionId: json['questionId'] as String,
      answer: json['answer'],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class ProctoringEventPayload {
  const ProctoringEventPayload({
    required this.attemptId,
    required this.type,
    required this.value,
    required this.timestamp,
  });

  final String attemptId;
  final ProctoringEventType type;
  final int value;
  final DateTime timestamp;

  factory ProctoringEventPayload.fromJson(Map<String, dynamic> json) {
    return ProctoringEventPayload(
      attemptId: json['attemptId'] as String,
      type: proctoringEventTypeFromString(json['type'] as String),
      value: json['value'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'attemptId': attemptId,
      'type': proctoringEventTypeToString(type),
      'value': value,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class ProctoringResponse {
  const ProctoringResponse({
    required this.accepted,
    required this.ignored,
  });

  final int accepted;
  final int ignored;

  factory ProctoringResponse.fromJson(Map<String, dynamic> json) {
    return ProctoringResponse(
      accepted: json['accepted'] as int? ?? 0,
      ignored: json['ignored'] as int? ?? 0,
    );
  }
}

class AttemptAudioChunk {
  const AttemptAudioChunk({
    required this.id,
    required this.attemptId,
    required this.chunkIndex,
    required this.mimeType,
    required this.byteSize,
    required this.startedAt,
    required this.endedAt,
    required this.createdAt,
    required this.fileUrl,
  });

  final String id;
  final String attemptId;
  final int chunkIndex;
  final String mimeType;
  final int byteSize;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final String fileUrl;

  factory AttemptAudioChunk.fromJson(Map<String, dynamic> json) {
    return AttemptAudioChunk(
      id: json['id'] as String,
      attemptId: json['attemptId'] as String,
      chunkIndex: (json['chunkIndex'] as num? ?? 0).toInt(),
      mimeType: json['mimeType'] as String? ?? 'audio/mp4',
      byteSize: (json['byteSize'] as num? ?? 0).toInt(),
      startedAt: (json['startedAt'] as String?) == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      endedAt: (json['endedAt'] as String?) == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      fileUrl: json['fileUrl'] as String? ?? '',
    );
  }
}

class SubmitResponse {
  const SubmitResponse({
    required this.id,
    required this.attemptId,
    required this.score,
    required this.correct,
    required this.wrong,
    required this.duration,
    required this.cheatScore,
    required this.riskLevel,
  });

  final String id;
  final String attemptId;
  final num score;
  final int correct;
  final int wrong;
  final int duration;
  final int cheatScore;
  final RiskLevel riskLevel;

  factory SubmitResponse.fromJson(Map<String, dynamic> json) {
    return SubmitResponse(
      id: json['id'] as String,
      attemptId: json['attemptId'] as String,
      score: json['score'] as num? ?? 0,
      correct: json['correct'] as int? ?? 0,
      wrong: json['wrong'] as int? ?? 0,
      duration: json['duration'] as int? ?? 0,
      cheatScore: json['cheatScore'] as int? ?? 0,
      riskLevel: riskLevelFromString(json['riskLevel'] as String? ?? 'safe'),
    );
  }

  ResultResponse toResultResponse() {
    return ResultResponse(
      id: id,
      attemptId: attemptId,
      examId: null,
      subjectId: null,
      classId: null,
      className: null,
      attemptNo: null,
      startTime: null,
      endTime: null,
      score: score,
      correct: correct,
      wrong: wrong,
      duration: duration,
      cheatScore: cheatScore,
      riskLevel: riskLevel,
      examTitle: null,
      subjectName: null,
      username: null,
    );
  }
}

class ResultResponse {
  const ResultResponse({
    required this.id,
    required this.attemptId,
    required this.examId,
    required this.subjectId,
    required this.classId,
    required this.className,
    required this.attemptNo,
    required this.startTime,
    required this.endTime,
    required this.score,
    required this.correct,
    required this.wrong,
    required this.duration,
    required this.cheatScore,
    required this.riskLevel,
    required this.examTitle,
    required this.subjectName,
    required this.username,
    this.proctoringReport,
  });

  final String id;
  final String attemptId;
  final String? examId;
  final String? subjectId;
  final String? classId;
  final String? className;
  final int? attemptNo;
  final DateTime? startTime;
  final DateTime? endTime;
  final num score;
  final int correct;
  final int wrong;
  final int duration;
  final int cheatScore;
  final RiskLevel riskLevel;
  final String? examTitle;
  final String? subjectName;
  final String? username;
  final ProctoringReport? proctoringReport;

  factory ResultResponse.fromJson(Map<String, dynamic> json) {
    return ResultResponse(
      id: json['id'] as String,
      attemptId: json['attemptId'] as String,
      examId: json['examId'] as String?,
      subjectId: json['subjectId'] as String?,
      classId: json['classId'] as String?,
      className: json['className'] as String?,
      attemptNo: (json['attemptNo'] as num?)?.toInt(),
      startTime: (json['startTime'] as String?) == null
          ? null
          : DateTime.parse(json['startTime'] as String),
      endTime: (json['endTime'] as String?) == null
          ? null
          : DateTime.parse(json['endTime'] as String),
      score: json['score'] as num? ?? 0,
      correct: json['correct'] as int? ?? 0,
      wrong: json['wrong'] as int? ?? 0,
      duration: json['duration'] as int? ?? 0,
      cheatScore: json['cheatScore'] as int? ?? 0,
      riskLevel: riskLevelFromString(json['riskLevel'] as String? ?? 'safe'),
      examTitle: json['examTitle'] as String?,
      subjectName: json['subjectName'] as String?,
      username: json['username'] as String?,
      proctoringReport:
          (json['proctoringReport'] as Map<String, dynamic>?) == null
              ? null
              : ProctoringReport.fromJson(
                  json['proctoringReport'] as Map<String, dynamic>,
                ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'attemptId': attemptId,
      'examId': examId,
      'subjectId': subjectId,
      'classId': classId,
      'className': className,
      'attemptNo': attemptNo,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'score': score,
      'correct': correct,
      'wrong': wrong,
      'duration': duration,
      'cheatScore': cheatScore,
      'riskLevel': riskLevelToString(riskLevel),
      'examTitle': examTitle,
      'subjectName': subjectName,
      'username': username,
      'proctoringReport': proctoringReport?.toJson(),
    };
  }
}

class ProctoringReport {
  const ProctoringReport({
    required this.totalEvents,
    required this.tabSwitchCount,
    required this.appBackgroundCount,
    required this.idleCount,
    required this.noiseCount,
    required this.maxIdleSeconds,
    required this.maxNoiseLevel,
    required this.notes,
  });

  final int totalEvents;
  final int tabSwitchCount;
  final int appBackgroundCount;
  final int idleCount;
  final int noiseCount;
  final int? maxIdleSeconds;
  final int? maxNoiseLevel;
  final List<String> notes;

  factory ProctoringReport.fromJson(Map<String, dynamic> json) {
    return ProctoringReport(
      totalEvents: (json['totalEvents'] as num? ?? 0).toInt(),
      tabSwitchCount: (json['tabSwitchCount'] as num? ?? 0).toInt(),
      appBackgroundCount: (json['appBackgroundCount'] as num? ?? 0).toInt(),
      idleCount: (json['idleCount'] as num? ?? 0).toInt(),
      noiseCount: (json['noiseCount'] as num? ?? 0).toInt(),
      maxIdleSeconds: (json['maxIdleSeconds'] as num?)?.toInt(),
      maxNoiseLevel: (json['maxNoiseLevel'] as num?)?.toInt(),
      notes: (json['notes'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'totalEvents': totalEvents,
      'tabSwitchCount': tabSwitchCount,
      'appBackgroundCount': appBackgroundCount,
      'idleCount': idleCount,
      'noiseCount': noiseCount,
      'maxIdleSeconds': maxIdleSeconds,
      'maxNoiseLevel': maxNoiseLevel,
      'notes': notes,
    };
  }
}

class AttemptAnswer {
  const AttemptAnswer({
    required this.questionId,
    required this.answer,
  });

  final String questionId;
  final Object? answer;
}

class AdminAttemptAnswer {
  const AdminAttemptAnswer({
    required this.questionId,
    required this.answer,
    required this.isCorrect,
    required this.question,
  });

  final String questionId;
  final Object? answer;
  final bool? isCorrect;
  final AdminQuestion? question;

  factory AdminAttemptAnswer.fromJson(Map<String, dynamic> json) {
    final rawQuestion = json['question'];
    final parsedQuestion = rawQuestion is Map<String, dynamic>
        ? AdminQuestion.fromJson(rawQuestion)
        : null;
    final questionId = (json['questionId'] as String?)?.trim();
    return AdminAttemptAnswer(
      questionId: (questionId != null && questionId.isNotEmpty)
          ? questionId
          : (parsedQuestion?.id ?? ''),
      answer: json['answer'],
      isCorrect: json['isCorrect'] as bool?,
      question: parsedQuestion,
    );
  }
}

class AttemptDetail {
  const AttemptDetail({
    required this.attempt,
    required this.answers,
    this.monitoring,
    this.serverNow,
    this.remainingSeconds,
  });

  final ApiAttempt attempt;
  final List<AttemptAnswer> answers;
  final AttemptMonitoringConfig? monitoring;
  final DateTime? serverNow;
  final int? remainingSeconds;

  factory AttemptDetail.fromJson(Map<String, dynamic> json) {
    final answers = <AttemptAnswer>[];
    final rawAnswers = json['answers'];
    if (rawAnswers is List<dynamic>) {
      for (final raw in rawAnswers) {
        if (raw is Map<String, dynamic>) {
          final questionId = raw['questionId'] as String?;
          if (questionId != null && questionId.isNotEmpty) {
            answers.add(
                AttemptAnswer(questionId: questionId, answer: raw['answer']));
          }
        }
      }
    }

    final attempt = ApiAttempt.fromJson(json);
    return AttemptDetail(
      attempt: attempt,
      answers: answers,
      monitoring: (json['monitoring'] as Map<String, dynamic>?) == null
          ? null
          : AttemptMonitoringConfig.fromJson(
              json['monitoring'] as Map<String, dynamic>,
            ),
      serverNow: (json['serverNow'] as String?) == null
          ? null
          : DateTime.parse(json['serverNow'] as String),
      remainingSeconds: json['remainingSeconds'] as int?,
    );
  }
}

class AuthScopedResults {
  const AuthScopedResults({
    required this.results,
    required this.role,
  });

  final List<ResultResponse> results;
  final UserRole role;
}
