import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthEvent { unauthorized }

final authEventBusProvider = Provider<AuthEventBus>((ref) {
  final bus = AuthEventBus();
  ref.onDispose(bus.dispose);
  return bus;
});

class AuthEventBus {
  final StreamController<AuthEvent> _controller =
      StreamController<AuthEvent>.broadcast();

  Stream<AuthEvent> get stream => _controller.stream;

  void emitUnauthorized() {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(AuthEvent.unauthorized);
  }

  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
