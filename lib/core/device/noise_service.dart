import 'dart:async';
import 'dart:math';

typedef NoiseSampler = Future<int> Function();
typedef OnNoise = void Function(int value);

class NoiseService {
  NoiseService({
    required this.interval,
    required this.onNoise,
    NoiseSampler? sampler,
  }) : _sampler = sampler ?? _defaultSampler;

  final Duration interval;
  final OnNoise onNoise;
  final NoiseSampler _sampler;
  Timer? _timer;
  bool _isRunning = false;

  void start() {
    if (_isRunning) {
      return;
    }
    _isRunning = true;
    _timer = Timer.periodic(interval, (_) async {
      final value = await _sampler();
      onNoise(value.clamp(0, 100));
    });
  }

  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
  }

  static Future<int> _defaultSampler() async {
    // Fallback sampler until a platform-specific microphone sampler is wired.
    return Random().nextInt(12);
  }
}
