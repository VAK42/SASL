import 'package:flutter/services.dart';
class HandLandmarkerService {
  static const platform = MethodChannel('com.sasl/handLandmarker');
  bool _isInitialized = false;
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      final result = await platform.invokeMethod('initDetector');
      _isInitialized = result == true;
      return _isInitialized;
    } catch (_) {
      return false;
    }
  }
  Future<List<double>?> processFrame(Uint8List imageBytes, int width, int height) async {
    if (!_isInitialized) return null;
    try {
      final result = await platform.invokeMethod('processFrame', {'imageBytes': imageBytes, 'width': width, 'height': height});
      if (result == null) return null;
      return List<double>.from(result.map((e) => e.toDouble()));
    } catch (_) {
      return null;
    }
  }
  Future<void> dispose() async {
    if (!_isInitialized) return;
    try {
      await platform.invokeMethod('dispose');
      _isInitialized = false;
    } catch (_) {}
  }
}