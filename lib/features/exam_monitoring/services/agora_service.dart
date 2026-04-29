import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'service_exception.dart';

enum AgoraServiceConnectionState {
  idle,
  connecting,
  connected,
  reconnecting,
  disconnected,
  failed,
}

class AgoraService {
  AgoraService();

  final ValueNotifier<AgoraServiceConnectionState> connectionState =
      ValueNotifier<AgoraServiceConnectionState>(
    AgoraServiceConnectionState.idle,
  );

  final ValueNotifier<Set<int>> remoteUids = ValueNotifier<Set<int>>(<int>{});

  final StreamController<ServiceException> _errorController =
      StreamController<ServiceException>.broadcast();

  Stream<ServiceException> get errors => _errorController.stream;

  RtcEngine? _engine;
  String? _appId;
  String? _channelName;
  int? _localUid;
  String? _joinToken;
  bool _isInitialized = false;
  bool _isJoined = false;

  RtcEngine? get engine => _engine;
  String? get channelName => _channelName;
  int? get localUid => _localUid;
  bool get isInitialized => _isInitialized;
  bool get isJoined => _isJoined;

  Future<void> initialize({
    required String appId,
  }) async {
    final trimmedAppId = appId.trim();
    if (trimmedAppId.isEmpty) {
      throw const ServiceException(
        'Agora App ID tidak boleh kosong.',
        code: 'agora.invalid_app_id',
      );
    }

    if (_isInitialized && _engine != null && _appId == trimmedAppId) {
      return;
    }

    await _disposeEngineInternal();

    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(
        RtcEngineContext(
          appId: trimmedAppId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      try {
        await engine.enableWebSdkInteroperability(true);
      } catch (_) {
        // Beberapa platform/build tidak membutuhkan atau tidak mendukung call ini.
      }
      engine.registerEventHandler(_buildEventHandler());
      await engine.enableVideo();
      await engine.enableAudio();

      _engine = engine;
      _appId = trimmedAppId;
      _isInitialized = true;
      _isJoined = false;
      _channelName = null;
      _localUid = null;
      _joinToken = null;
      connectionState.value = AgoraServiceConnectionState.idle;
      remoteUids.value = <int>{};
    } catch (error, stackTrace) {
      connectionState.value = AgoraServiceConnectionState.failed;
      throw ServiceException(
        'Inisialisasi Agora gagal.',
        code: 'agora.initialize_failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> joinChannel({
    required String channelName,
    required int uid,
    String? token,
    ClientRoleType role = ClientRoleType.clientRoleBroadcaster,
    bool publishCameraTrack = true,
    bool publishMicrophoneTrack = true,
    bool autoSubscribeAudio = true,
    bool autoSubscribeVideo = true,
    bool requestPermissions = true,
    bool startPreview = true,
  }) async {
    final trimmedChannel = channelName.trim();
    if (trimmedChannel.isEmpty) {
      throw const ServiceException(
        'Nama channel Agora tidak boleh kosong.',
        code: 'agora.invalid_channel',
      );
    }
    if (uid < 0) {
      throw const ServiceException(
        'UID Agora tidak valid.',
        code: 'agora.invalid_uid',
      );
    }

    final engine = _engine;
    if (!_isInitialized || engine == null) {
      throw const ServiceException(
        'AgoraService belum diinisialisasi.',
        code: 'agora.not_initialized',
      );
    }

    final normalizedToken = _normalizeToken(token);
    if (_isJoined && _channelName == trimmedChannel && _localUid == uid) {
      await renewToken(normalizedToken);
      return;
    }

    try {
      connectionState.value = AgoraServiceConnectionState.connecting;
      if (_isJoined) {
        await leaveChannel();
      }

      if (requestPermissions) {
        await _ensurePermissions();
      }

      await engine.setClientRole(
        role: role,
      );
      if (startPreview) {
        await engine.startPreview();
      }
      await engine.joinChannel(
        token: normalizedToken ?? '',
        channelId: trimmedChannel,
        uid: uid,
        options: ChannelMediaOptions(
          publishCameraTrack: publishCameraTrack,
          publishMicrophoneTrack: publishMicrophoneTrack,
          autoSubscribeAudio: autoSubscribeAudio,
          autoSubscribeVideo: autoSubscribeVideo,
          clientRoleType: role,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      _channelName = trimmedChannel;
      _localUid = uid;
      _joinToken = normalizedToken;
      _isJoined = true;
      connectionState.value = AgoraServiceConnectionState.connected;
    } catch (error, stackTrace) {
      connectionState.value = AgoraServiceConnectionState.failed;
      throw ServiceException(
        'Gagal join ke channel Agora.',
        code: 'agora.join_failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> leaveChannel() async {
    final engine = _engine;
    if (!_isInitialized || engine == null || !_isJoined) {
      return;
    }

    try {
      await engine.leaveChannel();
      await engine.stopPreview();
    } catch (error, stackTrace) {
      _emitError(
        ServiceException(
          'Gagal keluar dari channel Agora.',
          code: 'agora.leave_failed',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      _isJoined = false;
      _channelName = null;
      _localUid = null;
      _joinToken = null;
      remoteUids.value = <int>{};
      connectionState.value = AgoraServiceConnectionState.disconnected;
    }
  }

  Future<void> renewToken(String? token) async {
    final normalizedToken = _normalizeToken(token);
    if (normalizedToken == null) {
      return;
    }

    final engine = _engine;
    if (!_isInitialized || engine == null || !_isJoined) {
      return;
    }
    if (_joinToken == normalizedToken) {
      return;
    }

    try {
      await engine.renewToken(normalizedToken);
      _joinToken = normalizedToken;
    } catch (error, stackTrace) {
      throw ServiceException(
        'Gagal memperbarui token Agora.',
        code: 'agora.renew_token_failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> muteLocalAudio(bool muted) async {
    final engine = _engine;
    if (!_isInitialized || engine == null) {
      throw const ServiceException(
        'AgoraService belum diinisialisasi.',
        code: 'agora.not_initialized',
      );
    }
    try {
      await engine.muteLocalAudioStream(muted);
    } catch (error, stackTrace) {
      throw ServiceException(
        'Gagal mengubah status mikrofon.',
        code: 'agora.mute_audio_failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> muteLocalVideo(bool muted) async {
    final engine = _engine;
    if (!_isInitialized || engine == null) {
      throw const ServiceException(
        'AgoraService belum diinisialisasi.',
        code: 'agora.not_initialized',
      );
    }
    try {
      await engine.muteLocalVideoStream(muted);
    } catch (error, stackTrace) {
      throw ServiceException(
        'Gagal mengubah status kamera.',
        code: 'agora.mute_video_failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> switchCamera() async {
    final engine = _engine;
    if (!_isInitialized || engine == null) {
      throw const ServiceException(
        'AgoraService belum diinisialisasi.',
        code: 'agora.not_initialized',
      );
    }
    try {
      await engine.switchCamera();
    } catch (error, stackTrace) {
      throw ServiceException(
        'Gagal mengganti kamera.',
        code: 'agora.switch_camera_failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> dispose() async {
    await _disposeEngineInternal();
  }

  Future<void> _ensurePermissions() async {
    if (kIsWeb) {
      return;
    }

    try {
      final statuses = await <Permission>[
        Permission.microphone,
        Permission.camera,
      ].request();

      final microphoneGranted =
          statuses[Permission.microphone]?.isGranted ?? true;
      final cameraGranted = statuses[Permission.camera]?.isGranted ?? true;

      if (!microphoneGranted || !cameraGranted) {
        throw const ServiceException(
          'Izin kamera/mikrofon ditolak. Aktifkan izin untuk melanjutkan monitoring.',
          code: 'agora.permission_denied',
        );
      }
    } on ServiceException {
      rethrow;
    } catch (error, stackTrace) {
      throw ServiceException(
        'Gagal meminta izin kamera/mikrofon.',
        code: 'agora.permission_request_failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _disposeEngineInternal() async {
    final engine = _engine;
    if (engine == null) {
      _isInitialized = false;
      _isJoined = false;
      _channelName = null;
      _localUid = null;
      _joinToken = null;
      remoteUids.value = <int>{};
      connectionState.value = AgoraServiceConnectionState.idle;
      return;
    }

    try {
      if (_isJoined) {
        await engine.leaveChannel();
      }
    } catch (_) {
      // best effort
    }

    try {
      await engine.stopPreview();
    } catch (_) {
      // best effort
    }

    try {
      await engine.release();
    } catch (_) {
      // best effort
    }

    _engine = null;
    _isInitialized = false;
    _isJoined = false;
    _channelName = null;
    _localUid = null;
    _joinToken = null;
    remoteUids.value = <int>{};
    connectionState.value = AgoraServiceConnectionState.idle;
  }

  RtcEngineEventHandler _buildEventHandler() {
    return RtcEngineEventHandler(
      onError: (error, message) {
        connectionState.value = AgoraServiceConnectionState.failed;
        _emitError(
          ServiceException(
            'Agora error: $message',
            code: 'agora.runtime_error_$error',
          ),
        );
      },
      onJoinChannelSuccess: (_, __) {
        connectionState.value = AgoraServiceConnectionState.connected;
      },
      onLeaveChannel: (_, __) {
        _isJoined = false;
        remoteUids.value = <int>{};
        connectionState.value = AgoraServiceConnectionState.disconnected;
      },
      onConnectionStateChanged: (_, state, __) {
        switch (state) {
          case ConnectionStateType.connectionStateConnecting:
            connectionState.value = AgoraServiceConnectionState.connecting;
            break;
          case ConnectionStateType.connectionStateConnected:
            connectionState.value = AgoraServiceConnectionState.connected;
            break;
          case ConnectionStateType.connectionStateReconnecting:
            connectionState.value = AgoraServiceConnectionState.reconnecting;
            break;
          case ConnectionStateType.connectionStateDisconnected:
            connectionState.value = AgoraServiceConnectionState.disconnected;
            break;
          case ConnectionStateType.connectionStateFailed:
            connectionState.value = AgoraServiceConnectionState.failed;
            break;
        }
      },
      onUserJoined: (_, remoteUid, __) {
        final next = <int>{...remoteUids.value, remoteUid};
        remoteUids.value = next;
      },
      onUserOffline: (_, remoteUid, __) {
        final next = <int>{...remoteUids.value}..remove(remoteUid);
        remoteUids.value = next;
      },
    );
  }

  void _emitError(ServiceException exception) {
    if (_errorController.isClosed) {
      return;
    }
    _errorController.add(exception);
  }

  String? _normalizeToken(String? token) {
    final normalized = token?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
