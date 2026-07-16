package org.ciani01.noti

import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val SPLASH_THEME_CHANNEL = "org.ciani01.noti/splash_theme"
        private const val SPLASH_PREFERENCES = "noti_splash_theme"
        private const val SPLASH_COLOR_KEY = "background_color"
        private const val DEFAULT_SPLASH_COLOR = 0xFF5D55F6.toInt()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Android 12 shows its static system splash first. Once the activity
        // starts, use the last Flutter theme color for the remaining transition.
        val color = getSharedPreferences(SPLASH_PREFERENCES, MODE_PRIVATE)
            .getInt(SPLASH_COLOR_KEY, DEFAULT_SPLASH_COLOR)
        window.setBackgroundDrawable(ColorDrawable(color))
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPLASH_THEME_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "cacheBackgroundColor") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                // Dart's standard message codec represents integer values as a
                // Long on Android, even when the ARGB value fits in an Int.
                val color = (call.argument<Number>("argbColor"))?.toInt()
                if (color == null) {
                    result.error("invalid_color", "A splash color is required.", null)
                    return@setMethodCallHandler
                }

                getSharedPreferences(SPLASH_PREFERENCES, MODE_PRIVATE)
                    .edit()
                    .putInt(SPLASH_COLOR_KEY, color)
                    .apply()
                result.success(null)
            }
    }
}
