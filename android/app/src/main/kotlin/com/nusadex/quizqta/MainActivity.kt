package com.nusadex.quizqta

import android.Manifest
import android.graphics.RenderEffect
import android.graphics.Shader
import android.content.pm.PackageManager
import android.os.Build
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private var examSecurityEnabled = false
  private var privacyOverlay: View? = null
  private var pendingMicPermissionResult: MethodChannel.Result? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "enableExamSecurity" -> {
            setExamSecurityEnabled(true)
            result.success(null)
          }

          "disableExamSecurity" -> {
            setExamSecurityEnabled(false)
            result.success(null)
          }

          "enableSecure" -> {
            setExamSecurityEnabled(true)
            result.success(null)
          }

          "disableSecure" -> {
            setExamSecurityEnabled(false)
            result.success(null)
          }

          else -> result.notImplemented()
        }
      }

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOISE_CHANNEL_NAME)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "hasMicrophonePermission" -> {
            result.success(hasMicrophonePermission())
          }

          "requestMicrophonePermission" -> {
            requestMicrophonePermission(result)
          }

          else -> result.notImplemented()
        }
      }
  }

  override fun onPause() {
    super.onPause()
    if (examSecurityEnabled) {
      showPrivacyOverlay()
    }
  }

  override fun onResume() {
    super.onResume()
    if (examSecurityEnabled) {
      hidePrivacyOverlay()
    }
  }

  override fun onDestroy() {
    pendingMicPermissionResult = null
    hidePrivacyOverlay(remove = true)
    super.onDestroy()
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray,
  ) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    if (requestCode != MIC_PERMISSION_REQUEST_CODE) {
      return
    }

    val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
    pendingMicPermissionResult?.success(granted)
    pendingMicPermissionResult = null
  }

  private fun setExamSecurityEnabled(enabled: Boolean) {
    examSecurityEnabled = enabled
    if (enabled) {
      window.setFlags(
        WindowManager.LayoutParams.FLAG_SECURE,
        WindowManager.LayoutParams.FLAG_SECURE,
      )
      setHideOverlayWindowsCompat(true)
    } else {
      window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
      setHideOverlayWindowsCompat(false)
      hidePrivacyOverlay(remove = true)
      clearWindowBlur()
    }
  }

  private fun setHideOverlayWindowsCompat(enabled: Boolean) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
      return
    }

    try {
      val method = window.javaClass.getMethod(
        "setHideOverlayWindows",
        Boolean::class.javaPrimitiveType,
      )
      method.invoke(window, enabled)
    } catch (_: Throwable) {
      // Best-effort hardening; keep exam runtime working if API is unavailable.
    }
  }

  private fun hasMicrophonePermission(): Boolean {
    return ContextCompat.checkSelfPermission(
      this,
      Manifest.permission.RECORD_AUDIO,
    ) == PackageManager.PERMISSION_GRANTED
  }

  private fun requestMicrophonePermission(result: MethodChannel.Result) {
    if (hasMicrophonePermission()) {
      result.success(true)
      return
    }

    if (pendingMicPermissionResult != null) {
      result.error("permission_busy", "Microphone permission request is already in progress.", null)
      return
    }

    pendingMicPermissionResult = result
    ActivityCompat.requestPermissions(
      this,
      arrayOf(Manifest.permission.RECORD_AUDIO),
      MIC_PERMISSION_REQUEST_CODE,
    )
  }

  private fun showPrivacyOverlay() {
    if (!examSecurityEnabled) {
      return
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      window.decorView.setRenderEffect(
        RenderEffect.createBlurEffect(18f, 18f, Shader.TileMode.CLAMP),
      )
    }

    val overlay = ensurePrivacyOverlay()
    overlay.visibility = View.VISIBLE
    overlay.alpha = 1f
  }

  private fun hidePrivacyOverlay(remove: Boolean = false) {
    clearWindowBlur()
    val overlay = privacyOverlay ?: return
    if (remove) {
      val root = window.decorView.findViewById<FrameLayout>(android.R.id.content)
      root.removeView(overlay)
      privacyOverlay = null
      return
    }
    overlay.visibility = View.GONE
    overlay.alpha = 0f
  }

  private fun clearWindowBlur() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      window.decorView.setRenderEffect(null)
    }
  }

  private fun ensurePrivacyOverlay(): View {
    val existing = privacyOverlay
    if (existing != null) {
      return existing
    }

    val root = window.decorView.findViewById<FrameLayout>(android.R.id.content)
    val overlay = View(this).apply {
      setBackgroundColor(0xCC111827.toInt())
      visibility = View.GONE
      alpha = 0f
      isClickable = true
      importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
    }
    root.addView(
      overlay,
      FrameLayout.LayoutParams(
        FrameLayout.LayoutParams.MATCH_PARENT,
        FrameLayout.LayoutParams.MATCH_PARENT,
      ),
    )
    privacyOverlay = overlay
    return overlay
  }

  companion object {
    private const val CHANNEL_NAME = "app.screen_security"
    private const val NOISE_CHANNEL_NAME = "app.noise_service"
    private const val MIC_PERMISSION_REQUEST_CODE = 5107
  }
}
