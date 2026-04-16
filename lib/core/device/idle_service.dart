import 'dart:async';

import 'package:flutter/foundation.dart';

class IdleService {
  IdleService({required this.timeout, required this.onIdle});

  final Duration timeout;
  final VoidCallback onIdle;
  Timer? _timer;
  bool _isActive = false;

  void start() {
    _isActive = true;
    _schedule();
  }

  void reset() {
    if (!_isActive) return;
    _schedule();
  }

  void stop() {
    _timer?.cancel();
    _isActive = false;
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(timeout, onIdle);
  }
}
