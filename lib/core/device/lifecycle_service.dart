import 'dart:async';

import 'package:flutter/widgets.dart';

class LifecycleService with WidgetsBindingObserver {
  LifecycleService() {
    WidgetsBinding.instance.addObserver(this);
  }

  final StreamController<AppLifecycleState> _controller =
      StreamController<AppLifecycleState>.broadcast();

  Stream<AppLifecycleState> get stream => _controller.stream;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.add(state);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.close();
  }
}
