import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

import '../models/exam_student_status.dart';
import '../models/student_exam_session_config.dart';
import '../services/agora_service.dart';
import '../services/anti_cheat_service.dart';
import '../services/realtime_status_service.dart';
import '../services/service_exception.dart';

class StudentExamController extends ChangeNotifier {
  StudentExamController({
    AgoraService? agoraService,
    RealtimeStatusService? realtimeStatusService,
    AntiCheatService? antiCheatService,
  })  : _agoraService = agoraService ?? AgoraService(),
        _realtimeStatusService =
            realtimeStatusService ?? RealtimeStatusService(),
        _antiCheatService = antiCheatService ?? AntiCheatService();

  final AgoraService _agoraService;
  final RealtimeStatusService _realtimeStatusService;
  final AntiCheatService _antiCheatService;

  StreamSubscription<ServiceException>? _agoraErrorSubscription;
  StreamSubscription<ServiceException>? _realtimeErrorSubscription;

  bool _isDisposed = false;
  bool _isStarting = false;
  bool _isFinishing = false;
  bool _isReady = false;
  bool _isFinished = false;
  String? _errorMessage;
  ExamStudentStatus _status = ExamStudentStatus.offline;
  int _violations = 0;

  bool get isStarting => _isStarting;
  bool get isFinishing => _isFinishing;
  bool get isReady => _isReady;
  bool get isFinished => _isFinished;
  String? get errorMessage => _errorMessage;
  ExamStudentStatus get status => _status;
  int get violations => _violations;
  String? get firebasePath => _realtimeStatusService.statusPath;
  ValueListenable<Set<int>> get remoteUids => _agoraService.remoteUids;
  ValueListenable<AgoraServiceConnectionState> get agoraConnectionState =>
      _agoraService.connectionState;
  RtcEngine? get agoraEngine => _agoraService.engine;
  String? get agoraChannel => _agoraService.channelName;

  Future<void> start(StudentExamSessionConfig config) async {
    if (_isStarting || _isReady) {
      return;
    }

    _isStarting = true;
    _errorMessage = null;
    _status = ExamStudentStatus.offline;
    _violations = config.initialViolations;
    _safeNotify();

    await _attachServiceErrorListeners();

    try {
      var realtimeReady = false;
      try {
        await _realtimeStatusService.initialize(
          sessionId: config.sessionId,
          studentId: config.studentId,
          studentName: config.studentName,
          databaseUrl: config.firebaseDatabaseUrl,
          device: config.device,
          initialViolations: config.initialViolations,
        );
        await _realtimeStatusService.setStatus(ExamStudentStatus.active);
        realtimeReady = true;
      } on ServiceException catch (error) {
        if (!_canRunWithoutRealtime(error)) {
          rethrow;
        }
        _setError(
          'Monitoring realtime Firebase belum aktif di iOS. Kamera/mikrofon tetap digunakan untuk ujian.',
        );
      }

      await _agoraService.initialize(appId: config.agoraAppId);
      await _agoraService.joinChannel(
        channelName: config.agoraChannel,
        uid: config.agoraUid,
        token: config.agoraToken,
      );

      await _antiCheatService.start(
        onLeftApp: _handleLeftApp,
        onActive: _handleResumedActive,
        pauseThreshold: const Duration(seconds: 5),
        onError: (error) {
          _setError(error.message);
        },
      );

      _status = ExamStudentStatus.active;
      _violations = realtimeReady ? _realtimeStatusService.violations : 0;
      _isReady = true;
      _isFinished = false;
    } on ServiceException catch (error) {
      _setError(error.message);
      await _safeRollbackStartup();
    } catch (error, stackTrace) {
      _setError('Gagal memulai sesi ujian.');
      await _safeRollbackStartup(
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      _isStarting = false;
      _safeNotify();
    }
  }

  Future<void> finishExam() async {
    if (_isFinishing || !_isReady || _isFinished) {
      return;
    }

    _isFinishing = true;
    _errorMessage = null;
    _safeNotify();

    try {
      await _antiCheatService.stop();
      if (_realtimeStatusService.isInitialized) {
        await _realtimeStatusService.markFinished();
      }
      await _agoraService.leaveChannel();
      await _agoraService.dispose();

      _status = ExamStudentStatus.finished;
      _isFinished = true;
      _isReady = false;
    } on ServiceException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Gagal menandai ujian selesai.');
    } finally {
      _isFinishing = false;
      _safeNotify();
    }
  }

  Future<void> setMicrophoneMuted(bool muted) async {
    try {
      await _agoraService.muteLocalAudio(muted);
      if (muted) {
        await _registerManualViolation();
      }
    } on ServiceException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Gagal mengubah status mikrofon.');
    }
  }

  Future<void> setCameraMuted(bool muted) async {
    try {
      await _agoraService.muteLocalVideo(muted);
      if (muted) {
        await _registerManualViolation();
      }
    } on ServiceException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Gagal mengubah status kamera.');
    }
  }

  Future<void> switchCamera() async {
    try {
      await _agoraService.switchCamera();
    } on ServiceException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Gagal mengganti kamera.');
    }
  }

  Future<void> close() async {
    final alreadyFinished = _isFinished;
    _isReady = false;

    await _antiCheatService.stop();

    try {
      await _agoraService.leaveChannel();
      await _agoraService.dispose();
    } catch (_) {
      // best effort
    }

    try {
      await _realtimeStatusService.shutdown(
        markOffline: !alreadyFinished,
      );
    } catch (_) {
      // best effort
    }

    await _detachServiceErrorListeners();
    if (!alreadyFinished) {
      _status = ExamStudentStatus.offline;
    }
    _safeNotify();
  }

  Future<void> _handleLeftApp() async {
    if (!_isReady || _isFinished || !_realtimeStatusService.isInitialized) {
      return;
    }

    try {
      await _realtimeStatusService.setStatus(
        ExamStudentStatus.leftApp,
        incrementViolation: true,
      );
      _status = ExamStudentStatus.leftApp;
      _violations = _realtimeStatusService.violations;
      _safeNotify();
    } on ServiceException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Gagal mengirim status LEFT_APP.');
    }
  }

  Future<void> _handleResumedActive() async {
    if (!_isReady || _isFinished || !_realtimeStatusService.isInitialized) {
      return;
    }

    try {
      await _realtimeStatusService.setStatus(ExamStudentStatus.active);
      _status = ExamStudentStatus.active;
      _safeNotify();
    } on ServiceException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Gagal mengirim status ACTIVE.');
    }
  }

  Future<void> _registerManualViolation() async {
    if (!_realtimeStatusService.isInitialized) {
      return;
    }

    try {
      final nextViolations = _realtimeStatusService.violations + 1;
      await _realtimeStatusService.updateViolations(nextViolations);
      _violations = _realtimeStatusService.violations;
      _safeNotify();
    } on ServiceException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Gagal menandai pelanggaran monitoring.');
    }
  }

  Future<void> _attachServiceErrorListeners() async {
    await _detachServiceErrorListeners();
    _agoraErrorSubscription = _agoraService.errors.listen((error) {
      _setError(error.message);
    });
    _realtimeErrorSubscription = _realtimeStatusService.errors.listen((error) {
      _setError(error.message);
    });
  }

  Future<void> _detachServiceErrorListeners() async {
    await _agoraErrorSubscription?.cancel();
    await _realtimeErrorSubscription?.cancel();
    _agoraErrorSubscription = null;
    _realtimeErrorSubscription = null;
  }

  Future<void> _safeRollbackStartup({
    Object? cause,
    StackTrace? stackTrace,
  }) async {
    if (cause != null && stackTrace != null) {
      _setError('Gagal memulai sesi ujian: $cause');
    }

    try {
      await _antiCheatService.stop();
    } catch (_) {
      // best effort
    }
    try {
      await _agoraService.leaveChannel();
      await _agoraService.dispose();
    } catch (_) {
      // best effort
    }
    try {
      await _realtimeStatusService.shutdown(markOffline: true);
    } catch (_) {
      // best effort
    }

    _status = ExamStudentStatus.offline;
    _isReady = false;
    _isFinished = false;
  }

  void _setError(String message) {
    _errorMessage = message;
    _safeNotify();
  }

  void _safeNotify() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  bool _canRunWithoutRealtime(ServiceException error) {
    return error.code == 'realtime.unsupported_platform';
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_detachServiceErrorListeners());
    unawaited(_antiCheatService.stop());
    super.dispose();
  }
}
