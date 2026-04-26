import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

import '../services/agora_service.dart';
import '../services/service_exception.dart';

class AdminProctorWatchController extends ChangeNotifier {
  AdminProctorWatchController({
    AgoraService? agoraService,
  }) : _agoraService = agoraService ?? AgoraService();

  final AgoraService _agoraService;
  StreamSubscription<ServiceException>? _errorSubscription;

  bool _isDisposed = false;
  bool _isStarting = false;
  bool _isReady = false;
  String? _errorMessage;
  String? _channelName;

  bool get isStarting => _isStarting;
  bool get isReady => _isReady;
  String? get errorMessage => _errorMessage;
  String? get channelName => _channelName;
  ValueListenable<Set<int>> get remoteUids => _agoraService.remoteUids;
  ValueListenable<AgoraServiceConnectionState> get connectionState =>
      _agoraService.connectionState;
  RtcEngine? get agoraEngine => _agoraService.engine;

  Future<void> start({
    required String appId,
    required String channelName,
    required int uid,
    String? token,
  }) async {
    if (_isStarting) {
      return;
    }
    if (_isReady &&
        _channelName == channelName &&
        _agoraService.localUid == uid) {
      await renewToken(token);
      return;
    }

    _isStarting = true;
    _errorMessage = null;
    _safeNotify();

    await _errorSubscription?.cancel();
    _errorSubscription = _agoraService.errors.listen((error) {
      _errorMessage = error.message;
      _safeNotify();
    });

    try {
      await _agoraService.initialize(appId: appId);
      await _agoraService.joinChannel(
        channelName: channelName,
        uid: uid,
        token: token,
        role: ClientRoleType.clientRoleAudience,
        publishCameraTrack: false,
        publishMicrophoneTrack: false,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        requestPermissions: false,
        startPreview: false,
      );

      _channelName = channelName;
      _isReady = true;
    } on ServiceException catch (error) {
      _errorMessage = error.message;
      _isReady = false;
    } catch (_) {
      _errorMessage = 'Gagal membuka ruang pengawasan kamera.';
      _isReady = false;
    } finally {
      _isStarting = false;
      _safeNotify();
    }
  }

  Future<void> renewToken(String? token) async {
    try {
      await _agoraService.renewToken(token);
    } on ServiceException catch (error) {
      _errorMessage = error.message;
      _safeNotify();
    } catch (_) {
      _errorMessage = 'Gagal memperbarui token ruang pengawasan.';
      _safeNotify();
    }
  }

  Future<void> close() async {
    await _errorSubscription?.cancel();
    _errorSubscription = null;

    try {
      await _agoraService.leaveChannel();
      await _agoraService.dispose();
    } catch (_) {
      // best effort
    }

    _isReady = false;
    _channelName = null;
    _safeNotify();
  }

  void _safeNotify() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_errorSubscription?.cancel());
    super.dispose();
  }
}
