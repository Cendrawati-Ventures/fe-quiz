import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:online_exam_system/firebase_options.dart';

import '../models/exam_student_status.dart';
import '../models/student_presence.dart';
import 'service_exception.dart';

class RealtimeStatusService {
  RealtimeStatusService._internal();

  static final RealtimeStatusService _instance =
      RealtimeStatusService._internal();

  factory RealtimeStatusService() => _instance;

  static bool _persistenceConfigured = false;

  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<bool> isFirebaseConnected = ValueNotifier<bool>(false);
  final StreamController<ServiceException> _errorController =
      StreamController<ServiceException>.broadcast();

  FirebaseDatabase? _database;
  String? _databaseUrl;
  DatabaseReference? _studentRef;
  DatabaseReference? _connectedRef;
  StreamSubscription<DatabaseEvent>? _firebaseConnectionSubscription;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  String? _sessionId;
  String? _studentId;
  String _studentName = '';
  String _device = Platform.operatingSystem;
  int _violations = 0;
  int _reconnectAttempts = 0;
  bool _isInitialized = false;
  bool _hasNetwork = true;
  ExamStudentStatus _currentStatus = ExamStudentStatus.offline;

  Stream<ServiceException> get errors => _errorController.stream;
  bool get isInitialized => _isInitialized;
  ExamStudentStatus get currentStatus => _currentStatus;
  int get violations => _violations;
  String? get sessionId => _sessionId;
  String? get studentId => _studentId;
  String? get statusPath {
    final sessionId = _sessionId;
    final studentId = _studentId;
    if (sessionId == null || studentId == null) {
      return null;
    }
    return '/examSessions/$sessionId/students/$studentId';
  }

  Future<void> initialize({
    required String sessionId,
    required String studentId,
    required String studentName,
    String? databaseUrl,
    String? device,
    int initialViolations = 0,
  }) async {
    final trimmedSessionId = sessionId.trim();
    final trimmedStudentId = studentId.trim();
    final trimmedName = studentName.trim();
    final trimmedDatabaseUrl = databaseUrl?.trim() ?? '';
    final trimmedDevice = (device ?? Platform.operatingSystem).trim();

    if (trimmedSessionId.isEmpty) {
      throw const ServiceException(
        'Session ID tidak boleh kosong.',
        code: 'realtime.invalid_session_id',
      );
    }
    if (trimmedStudentId.isEmpty) {
      throw const ServiceException(
        'Student ID tidak boleh kosong.',
        code: 'realtime.invalid_student_id',
      );
    }
    if (trimmedName.isEmpty) {
      throw const ServiceException(
        'Nama student tidak boleh kosong.',
        code: 'realtime.invalid_student_name',
      );
    }

    await _detachListenersAndTimers();
    _databaseUrl = trimmedDatabaseUrl.isEmpty ? null : trimmedDatabaseUrl;
    await _ensureFirebaseInitialized();

    _sessionId = trimmedSessionId;
    _studentId = trimmedStudentId;
    _studentName = trimmedName;
    _device = trimmedDevice.isEmpty ? Platform.operatingSystem : trimmedDevice;
    _violations = max(0, initialViolations);
    _currentStatus = ExamStudentStatus.active;
    _isInitialized = true;

    final database = _requireDatabase();
    _studentRef = database.ref(
      'examSessions/$trimmedSessionId/students/$trimmedStudentId',
    );
    _connectedRef = database.ref('.info/connected');

    _firebaseConnectionSubscription = _connectedRef!.onValue.listen(
      _onFirebaseConnectionChanged,
      onError: (error, stackTrace) {
        _emitError(
          ServiceException(
            'Listener koneksi Firebase gagal.',
            code: 'realtime.connection_listener_failed',
            cause: error,
            stackTrace: stackTrace is StackTrace ? stackTrace : null,
          ),
        );
        _scheduleReconnect();
      },
    );

    _networkSubscription = _connectivity.onConnectivityChanged.listen(
      _onNetworkChanged,
      onError: (error, stackTrace) {
        _emitError(
          ServiceException(
            'Listener jaringan gagal.',
            code: 'realtime.network_listener_failed',
            cause: error,
            stackTrace: stackTrace is StackTrace ? stackTrace : null,
          ),
        );
      },
    );

    final connectivity = await _connectivity.checkConnectivity();
    _hasNetwork = _resolveHasNetwork(connectivity);
    if (_hasNetwork) {
      database.goOnline();
    } else {
      database.goOffline();
    }

    _startHeartbeat();
    _scheduleReconnect(immediate: true);
  }

  Future<void> setStatus(
    ExamStudentStatus status, {
    bool incrementViolation = false,
  }) async {
    _ensureServiceReady();

    if (incrementViolation && status == ExamStudentStatus.leftApp) {
      _violations += 1;
    }
    _currentStatus = status;

    try {
      await _writeCurrentPresence();
    } on ServiceException {
      rethrow;
    } catch (error, stackTrace) {
      throw ServiceException(
        'Gagal mengirim status $status ke Firebase.',
        code: 'realtime.set_status_failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> updateViolations(int violations) async {
    _ensureServiceReady();
    _violations = max(0, violations);
    await _writeCurrentPresence();
  }

  Future<void> markFinished() async {
    await setStatus(ExamStudentStatus.finished);
  }

  Future<void> markOffline() async {
    await setStatus(ExamStudentStatus.offline);
  }

  Future<void> shutdown({
    bool markOffline = true,
  }) async {
    if (!_isInitialized) {
      return;
    }

    final shouldMarkOffline =
        markOffline && _currentStatus != ExamStudentStatus.finished;
    if (shouldMarkOffline) {
      _currentStatus = ExamStudentStatus.offline;
      try {
        await _writeCurrentPresence(
          allowReconnectScheduling: false,
        );
      } catch (_) {
        // best effort
      }
    }

    await _detachListenersAndTimers();
    isFirebaseConnected.value = false;
    _isInitialized = false;
    _sessionId = null;
    _studentId = null;
    _studentRef = null;
    _connectedRef = null;
    _reconnectAttempts = 0;
  }

  void _onFirebaseConnectionChanged(DatabaseEvent event) {
    final connected = event.snapshot.value == true;
    isFirebaseConnected.value = connected;

    if (connected) {
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      unawaited(_setupOnDisconnect());
      unawaited(_writeCurrentPresence());
      return;
    }

    _scheduleReconnect();
  }

  void _onNetworkChanged(List<ConnectivityResult> results) {
    _hasNetwork = _resolveHasNetwork(results);
    final database = _database;
    if (database == null) {
      return;
    }

    if (_hasNetwork) {
      database.goOnline();
      _scheduleReconnect(immediate: true);
    } else {
      database.goOffline();
      isFirebaseConnected.value = false;
    }
  }

  bool _resolveHasNetwork(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_sendHeartbeat());
    });
  }

  Future<void> _sendHeartbeat() async {
    if (!_isInitialized || _currentStatus == ExamStudentStatus.offline) {
      return;
    }
    final studentRef = _studentRef;
    if (studentRef == null) {
      return;
    }

    try {
      await studentRef.update(<String, Object?>{
        'lastSeen': ServerValue.timestamp,
        'connection': isFirebaseConnected.value,
      });
    } catch (error, stackTrace) {
      _emitError(
        ServiceException(
          'Heartbeat Firebase gagal.',
          code: 'realtime.heartbeat_failed',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
      _scheduleReconnect();
    }
  }

  Future<void> _writeCurrentPresence({
    bool allowReconnectScheduling = true,
  }) async {
    final payload = StudentPresence(
      name: _studentName,
      status: _currentStatus,
      violations: _violations,
      device: _device,
      connection: _currentStatus != ExamStudentStatus.offline,
    ).toMap();

    await _writeWithRetry(
      payload,
      allowReconnectScheduling: allowReconnectScheduling,
    );
  }

  Future<void> _writeWithRetry(
    Map<String, dynamic> payload, {
    bool allowReconnectScheduling = true,
  }) async {
    final studentRef = _studentRef;
    if (studentRef == null) {
      throw const ServiceException(
        'Firebase student reference belum siap.',
        code: 'realtime.student_ref_missing',
      );
    }

    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await studentRef.update(payload);
        return;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
        }
      }
    }

    if (allowReconnectScheduling) {
      _scheduleReconnect();
    }

    throw ServiceException(
      'Gagal menulis status ke Firebase setelah retry.',
      code: 'realtime.write_failed',
      cause: lastError,
      stackTrace: lastStackTrace,
    );
  }

  Future<void> _setupOnDisconnect() async {
    final studentRef = _studentRef;
    if (studentRef == null) {
      return;
    }

    try {
      await studentRef.onDisconnect().update(
            StudentPresence(
              name: _studentName,
              status: ExamStudentStatus.offline,
              violations: _violations,
              device: _device,
              connection: false,
            ).toMap(),
          );
    } catch (error, stackTrace) {
      _emitError(
        ServiceException(
          'Registrasi onDisconnect Firebase gagal.',
          code: 'realtime.on_disconnect_failed',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void _scheduleReconnect({
    bool immediate = false,
  }) {
    if (!_isInitialized || !_hasNetwork) {
      return;
    }
    if (_reconnectTimer != null) {
      return;
    }

    final delay = immediate
        ? Duration.zero
        : Duration(
            seconds: min(30, 1 << min(_reconnectAttempts, 5)),
          );

    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;
      if (!_isInitialized) {
        return;
      }

      _reconnectAttempts += 1;
      final database = _database;
      if (database == null) {
        return;
      }

      try {
        database.goOnline();
        await _setupOnDisconnect();
        await _writeCurrentPresence(
          allowReconnectScheduling: false,
        );
        _reconnectAttempts = 0;
      } catch (error, stackTrace) {
        _emitError(
          ServiceException(
            'Reconnect Firebase gagal.',
            code: 'realtime.reconnect_failed',
            cause: error,
            stackTrace: stackTrace,
          ),
        );
        _scheduleReconnect();
      }
    });
  }

  Future<void> _ensureFirebaseInitialized() async {
    try {
      if (Firebase.apps.isEmpty) {
        if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
          throw const ServiceException(
            'Firebase monitoring belum dikonfigurasi untuk platform ini.',
            code: 'realtime.unsupported_platform',
          );
        }

        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } on ServiceException {
      rethrow;
    } catch (error, stackTrace) {
      throw ServiceException(
        'Firebase belum berhasil diinisialisasi.',
        code: 'realtime.firebase_init_failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    final app = Firebase.app();
    final databaseUrl = _databaseUrl;
    if (databaseUrl != null && databaseUrl.isNotEmpty) {
      _database = FirebaseDatabase.instanceFor(
        app: app,
        databaseURL: databaseUrl,
      );
    } else {
      _database = FirebaseDatabase.instanceFor(app: app);
    }
    if (_persistenceConfigured) {
      return;
    }

    try {
      _database!.setPersistenceEnabled(true);
      _database!.setPersistenceCacheSizeBytes(10 * 1024 * 1024);
    } catch (_) {
      // Pengaturan persistence bisa gagal jika database sudah terpakai.
    } finally {
      _persistenceConfigured = true;
    }
  }

  FirebaseDatabase _requireDatabase() {
    final database = _database;
    if (database == null) {
      throw const ServiceException(
        'Firebase Database belum siap.',
        code: 'realtime.database_missing',
      );
    }
    return database;
  }

  void _ensureServiceReady() {
    if (!_isInitialized) {
      throw const ServiceException(
        'RealtimeStatusService belum diinisialisasi.',
        code: 'realtime.not_initialized',
      );
    }
  }

  Future<void> _detachListenersAndTimers() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _firebaseConnectionSubscription?.cancel();
    _firebaseConnectionSubscription = null;

    await _networkSubscription?.cancel();
    _networkSubscription = null;
  }

  void _emitError(ServiceException exception) {
    if (_errorController.isClosed) {
      return;
    }
    _errorController.add(exception);
  }
}
