import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenSecurity {
  ScreenSecurity._();

  static const MethodChannel _channel = MethodChannel('app.screen_security');

  static Future<void> enableSecureFlag() async {
    await _invokeExamSecurity(enable: true);
  }

  static Future<void> disableSecureFlag() async {
    await _invokeExamSecurity(enable: false);
  }

  static Future<void> _invokeExamSecurity({required bool enable}) async {
    final method = enable ? 'enableExamSecurity' : 'disableExamSecurity';
    final legacyMethod = enable ? 'enableSecure' : 'disableSecure';
    await _invokeAndroidOnly(method, fallbackMethod: legacyMethod);
  }

  static Future<void> _invokeAndroidOnly(
    String method, {
    String? fallbackMethod,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      if (fallbackMethod != null) {
        await _invokeAndroidOnly(fallbackMethod);
      }
    } on PlatformException {
      if (fallbackMethod != null) {
        await _invokeAndroidOnly(fallbackMethod);
      }
    }
  }
}
