import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/model/auth_user.dart';
import '../../exam/state/exam_state.dart';
import '../controllers/student_exam_controller.dart';
import '../models/student_exam_session_config.dart';

final studentMonitoringSessionProvider =
    Provider<StudentMonitoringSession>((ref) {
  final session = StudentMonitoringSession();
  ref.onDispose(() {
    unawaited(session.disposeAsync());
  });
  return session;
});

class StudentMonitoringSession extends ChangeNotifier {
  StudentMonitoringSession({
    StudentExamController? controller,
  }) : _controller = controller ?? StudentExamController() {
    _controller.addListener(_relayControllerState);
  }

  final StudentExamController _controller;

  String? _activeAttemptId;
  bool _isDisposed = false;

  StudentExamController get controller => _controller;
  String? get activeAttemptId => _activeAttemptId;
  bool get isReady => _controller.isReady;
  bool get isStarting => _controller.isStarting;
  bool get isFinishing => _controller.isFinishing;
  String? get errorMessage => _controller.errorMessage;
  String? get startupMessage => _controller.startupMessage;

  Future<void> ensureStarted(StudentExamSessionConfig config) async {
    if (_isDisposed) {
      return;
    }

    if (_activeAttemptId == config.sessionId &&
        (_controller.isReady || _controller.isStarting)) {
      return;
    }

    if (_activeAttemptId != null && _activeAttemptId != config.sessionId) {
      await stop(markFinished: false);
    }

    _activeAttemptId = config.sessionId;
    _relayControllerState();
    await _controller.start(config);
    _relayControllerState();
  }

  Future<void> stop({required bool markFinished}) async {
    if (_isDisposed) {
      return;
    }

    if (markFinished) {
      await _controller.finishExam();
    }
    await _controller.close();
    _activeAttemptId = null;
    _relayControllerState();
  }

  Future<void> disposeAsync() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _controller.removeListener(_relayControllerState);
    await _controller.close();
    _controller.dispose();
    _activeAttemptId = null;
  }

  void _relayControllerState() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }
}

StudentExamSessionConfig? resolveStudentMonitoringConfig({
  required AuthUser? user,
  required ExamSessionState sessionState,
}) {
  final attempt = sessionState.attempt;
  final monitoring = sessionState.monitoring;
  if (user == null ||
      !sessionState.hasActiveAttempt ||
      attempt == null ||
      monitoring == null ||
      !monitoring.enabled) {
    return null;
  }

  final appId = monitoring.agoraAppId?.trim() ?? '';
  final channel = monitoring.agoraChannel?.trim() ?? '';
  final uid = monitoring.agoraUid ?? -1;
  if (appId.isEmpty || channel.isEmpty || uid < 0) {
    return null;
  }

  return StudentExamSessionConfig(
    sessionId: attempt.id,
    studentId: user.id,
    studentName: user.effectiveDisplayName,
    agoraAppId: appId,
    agoraChannel: channel,
    agoraUid: uid,
    agoraToken: monitoring.agoraToken,
    firebaseDatabaseUrl: monitoring.firebaseDatabaseUrl,
    device: null,
    initialViolations: 0,
  );
}
