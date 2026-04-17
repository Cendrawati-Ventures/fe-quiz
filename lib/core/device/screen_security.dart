import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenSecurity {
  ScreenSecurity._();

  static const MethodChannel _channel = MethodChannel('app.screen_security');

  static Future<void> enableSecureFlag() async {
    await _invokeAndroidOnly('enableSecure');
  }

  static Future<void> disableSecureFlag() async {
    await _invokeAndroidOnly('disableSecure');
  }

  static Future<void> _invokeAndroidOnly(String method) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Ignore when native bridge is unavailable.
    } on PlatformException {
      // Ignore to avoid blocking exam session when secure flag fails.
    }
  }
}
