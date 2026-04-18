import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:noise_meter/noise_meter.dart';

typedef OnNoise = void Function(int value);
typedef NoiseSampler = Future<int> Function();

class NoiseService {
  NoiseService({
    required this.interval,
    required this.onNoise,
    NoiseSampler? sampler,
  }) : _customSampler = sampler;

  static const MethodChannel _permissionChannel =
      MethodChannel('app.noise_service');

  final Duration interval;
  final OnNoise onNoise;
  final NoiseSampler? _customSampler;

  Timer? _timer;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  NoiseMeter? _noiseMeter;
  bool _isRunning = false;
  int _latestAmplitude = 0;

  void start() {
    if (_isRunning) {
      return;
    }
    _isRunning = true;

    final sampler = _customSampler;
    if (sampler != null) {
      _timer = Timer.periodic(interval, (_) async {
        final value = await sampler();
        onNoise(value.clamp(0, 100));
      });
      return;
    }

    _timer = Timer.periodic(interval, (_) {
      onNoise(_latestAmplitude.clamp(0, 100));
    });
    _startMicrophoneStream();
  }

  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    _noiseSubscription?.cancel();
    _noiseSubscription = null;
    _latestAmplitude = 0;
  }

  Future<void> _startMicrophoneStream() async {
    final canReadMicrophone = await _ensureMicrophonePermission();
    if (!canReadMicrophone || !_isRunning) {
      return;
    }

    _noiseMeter ??= NoiseMeter();
    await _noiseSubscription?.cancel();
    _noiseSubscription = _noiseMeter!.noise.listen(
      (reading) {
        _latestAmplitude = _normalizeReading(reading);
      },
      onError: (_) {
        _latestAmplitude = 0;
      },
      cancelOnError: false,
    );
  }

  Future<bool> _ensureMicrophonePermission() async {
    if (kIsWeb) {
      return false;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    try {
      final hasPermission = await _permissionChannel.invokeMethod<bool>(
            'hasMicrophonePermission',
          ) ??
          false;
      if (hasPermission) {
        return true;
      }

      final granted = await _permissionChannel.invokeMethod<bool>(
            'requestMicrophonePermission',
          ) ??
          false;
      return granted;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  int _normalizeReading(NoiseReading reading) {
    final mean = reading.meanDecibel.isFinite ? reading.meanDecibel : 0.0;
    final maxDecibel = reading.maxDecibel.isFinite ? reading.maxDecibel : mean;
    final decibel = mean > maxDecibel ? mean : maxDecibel;
    final clamped = decibel.clamp(0.0, 120.0).toDouble();
    return ((clamped / 120.0) * 100).round();
  }
}
