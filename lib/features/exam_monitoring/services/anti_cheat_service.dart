import 'dart:async';

import 'package:flutter/widgets.dart';

import 'service_exception.dart';

typedef AntiCheatStatusCallback = Future<void> Function();
typedef AntiCheatErrorCallback = void Function(ServiceException error);

class AntiCheatService with WidgetsBindingObserver {
  AntiCheatService._internal();

  static final AntiCheatService _instance = AntiCheatService._internal();

  factory AntiCheatService() => _instance;

  Duration _pauseThreshold = const Duration(seconds: 5);
  Timer? _pauseTimer;
  AntiCheatStatusCallback? _onLeftApp;
  AntiCheatStatusCallback? _onActive;
  AntiCheatErrorCallback? _onError;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<void> start({
    required AntiCheatStatusCallback onLeftApp,
    required AntiCheatStatusCallback onActive,
    AntiCheatErrorCallback? onError,
    Duration pauseThreshold = const Duration(seconds: 5),
  }) async {
    _pauseThreshold = pauseThreshold;
    _onLeftApp = onLeftApp;
    _onActive = onActive;
    _onError = onError;

    if (_isRunning) {
      return;
    }

    WidgetsBinding.instance.addObserver(this);
    _isRunning = true;
  }

  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    _pauseTimer?.cancel();
    _pauseTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    _isRunning = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isRunning) {
      return;
    }

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _scheduleLeftApp();
        break;
      case AppLifecycleState.resumed:
        _pauseTimer?.cancel();
        _pauseTimer = null;
        _safeCall(_onActive);
        break;
      case AppLifecycleState.hidden:
        _scheduleLeftApp();
        break;
    }
  }

  void _scheduleLeftApp() {
    _pauseTimer?.cancel();
    _pauseTimer = Timer(_pauseThreshold, () {
      _safeCall(_onLeftApp);
    });
  }

  void _safeCall(AntiCheatStatusCallback? callback) {
    if (callback == null) {
      return;
    }
    unawaited(
      callback().catchError((error, stackTrace) {
        _onError?.call(
          ServiceException(
            'Terjadi kesalahan pada callback anti-cheat.',
            code: 'anti_cheat.callback_failed',
            cause: error,
            stackTrace: stackTrace is StackTrace ? stackTrace : null,
          ),
        );
      }),
    );
  }
}
