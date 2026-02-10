package com.sasl.sasl
import android.content.Context
import android.graphics.Bitmap
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
class HandLandmarkerHelper(private val context: Context) {
  private var handLandmarker: HandLandmarker? = null
  fun initialize(): Boolean {
    return try {
      android.util.Log.d("HandLandmarker", "Initializing MediaPipe...")
      val baseOptions = BaseOptions.builder()
        .setModelAssetPath("models/hand_landmarker.task")
        .build()
      val options = HandLandmarker.HandLandmarkerOptions.builder()
        .setBaseOptions(baseOptions)
        .setRunningMode(RunningMode.IMAGE)
        .setNumHands(1)
        .setMinHandDetectionConfidence(0.5f)
        .setMinTrackingConfidence(0.5f)
        .setMinHandPresenceConfidence(0.5f)
        .build()
      handLandmarker = HandLandmarker.createFromOptions(context, options)
      android.util.Log.d("HandLandmarker", "MediaPipe Initialized Successfully")
      true
    } catch (e: Exception) {
      android.util.Log.e("HandLandmarker", "Init Failed: ${e.message}")
      e.printStackTrace()
      false
    }
  }
  fun detectLandmarks(bitmap: Bitmap): List<Float>? {
    return try {
      android.util.Log.d("HandLandmarker", "Processing Bitmap: ${bitmap.width}x${bitmap.height}")
      val mpImage = BitmapImageBuilder(bitmap).build()
      val result: HandLandmarkerResult? = handLandmarker?.detect(mpImage)
      android.util.Log.d("HandLandmarker", "Hands Detected: ${result?.landmarks()?.size ?: 0}")
      if (result != null && result.landmarks().isNotEmpty()) {
        val landmarks = mutableListOf<Float>()
        for (lm in result.landmarks()[0]) {
          landmarks.add(lm.x())
          landmarks.add(lm.y())
          landmarks.add(lm.z())
        }
        android.util.Log.d("HandLandmarker", "Returning ${landmarks.size} Values")
        landmarks
      } else {
        android.util.Log.d("HandLandmarker", "No Landmarks Found")
        null
      }
    } catch (e: Exception) {
      android.util.Log.e("HandLandmarker", "Detection Error: ${e.message}")
      e.printStackTrace()
      null
    }
  }
  fun close() {
    handLandmarker?.close()
    handLandmarker = null
  }
}