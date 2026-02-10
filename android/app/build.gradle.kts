plugins {
  id("com.android.application")
  id("kotlin-android")
  id("dev.flutter.flutter-gradle-plugin")
}
android {
  namespace = "com.sasl.sasl"
  compileSdk = flutter.compileSdkVersion
  ndkVersion = flutter.ndkVersion
  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }
  kotlinOptions {
    jvmTarget = JavaVersion.VERSION_17.toString()
  }
  defaultConfig {
    applicationId = "com.sasl.sasl"
    minSdk = 24
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName
  }
  aaptOptions {
    noCompress += listOf("tflite", "task")
  }
  buildTypes {
    release {
      signingConfig = signingConfigs.getByName("debug")
    }
  }
}
dependencies {
  implementation("com.google.mediapipe:tasks-vision:0.10.32")
}
flutter {
  source = "../.."
}