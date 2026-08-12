package com.radiowhitelabel.radio_whitelabel

import com.ryanheise.audioservice.AudioServiceActivity
import android.os.Build
import android.app.PictureInPictureParams
import android.util.Rational
import android.content.res.Configuration
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var methodChannel: MethodChannel? = null
    private var isVideoPlaying = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pip_channel")
        
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "setPipActive") {
                isVideoPlaying = (call.arguments as? Boolean) ?: false
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onUserLeaveHint() {
        if (isVideoPlaying && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            enterPictureInPictureMode(params)
        }
        super.onUserLeaveHint()
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        methodChannel?.invokeMethod("pip_mode_changed", isInPictureInPictureMode)
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
    }
}
