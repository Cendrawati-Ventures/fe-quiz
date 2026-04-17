package com.example.online_exam_system

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "enableSecure" -> {
            window.setFlags(
              WindowManager.LayoutParams.FLAG_SECURE,
              WindowManager.LayoutParams.FLAG_SECURE,
            )
            result.success(null)
          }

          "disableSecure" -> {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            result.success(null)
          }

          else -> result.notImplemented()
        }
      }
  }

  companion object {
    private const val CHANNEL_NAME = "app.screen_security"
  }
}
