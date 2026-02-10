package com.sasl.sasl
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
class MainActivity : FlutterActivity() {
  private val channelName = "com.sasl/handLandmarker"
  private var handLandmarkerHelper: HandLandmarkerHelper? = null
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
      when (call.method) {
        "initDetector" -> {
          android.util.Log.d("MainActivity", "InitDetector Called")
          handLandmarkerHelper = HandLandmarkerHelper(this)
          val success = handLandmarkerHelper?.initialize() ?: false
          android.util.Log.d("MainActivity", "InitDetector Result: $success")
          result.success(success)
        }
        "processFrame" -> {
          val bytes = call.argument<ByteArray>("imageBytes")
          val width = call.argument<Int>("width")
          val height = call.argument<Int>("height")
          if (bytes != null && width != null && height != null) {
            val pixels = IntArray(width * height)
            for (i in pixels.indices) {
              val r = bytes[i * 4].toInt() and 0xFF
              val g = bytes[i * 4 + 1].toInt() and 0xFF
              val b = bytes[i * 4 + 2].toInt() and 0xFF
              val a = bytes[i * 4 + 3].toInt() and 0xFF
              pixels[i] = (a shl 24) or (r shl 16) or (g shl 8) or b
            }
            val bitmap = Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888)
            val landmarks = handLandmarkerHelper?.detectLandmarks(bitmap)
            result.success(landmarks)
          } else {
            result.success(null)
          }
        }
        "dispose" -> {
          handLandmarkerHelper?.close()
          handLandmarkerHelper = null
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }
}