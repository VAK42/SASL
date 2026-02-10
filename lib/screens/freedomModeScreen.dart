import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/handLandmarkerService.dart';
import '../services/signClassifierService.dart';
import '../widgets/tutorialOverlay.dart';
import '../widgets/cameraPreview.dart';
import '../widgets/handPainter.dart';
class FreedomModeScreen extends StatefulWidget {
  const FreedomModeScreen({super.key});
  @override
  State<FreedomModeScreen> createState() => _FreedomModeScreenState();
}
class _FreedomModeScreenState extends State<FreedomModeScreen> {
  CameraController? _cameraController;
  final _handLandmarkerService = HandLandmarkerService();
  final _signClassifierService = SignClassifierService();
  bool _isInitialized = false;
  List<double>? _currentLandmarks;
  String _predictedSign = '';
  double _confidence = 0.0;
  bool _isProcessing = false;
  bool _showTutorial = false;
  @override
  void initState() {
    super.initState();
    _showTutorial = !TutorialOverlay.hasSeenTutorial('freedom');
    _initializeCamera();
  }
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final camera = cameras.firstWhere((cam) => cam.lensDirection == CameraLensDirection.front);
      _cameraController = CameraController(camera, ResolutionPreset.medium, enableAudio: false);
      await _cameraController!.initialize();

      await _handLandmarkerService.initialize();
      await _signClassifierService.initialize();
      _cameraController!.startImageStream(_processFrame);
      setState(() => _isInitialized = true);
    } catch (_) {}
  }
  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      final bytes = _convertYUV420toImageBytes(image);
      final landmarks = await _handLandmarkerService.processFrame(bytes, image.width, image.height);
      if (landmarks != null && landmarks.length == 63) {

        final transformedLandmarks = List<double>.filled(63, 0);
        for (int i = 0; i < 21; i++) {
          transformedLandmarks[i * 3] = landmarks[i * 3 + 1];
          transformedLandmarks[i * 3 + 1] = landmarks[i * 3];
          transformedLandmarks[i * 3 + 2] = landmarks[i * 3 + 2];
        }
        final result = await _signClassifierService.predict(transformedLandmarks);
        if (result != null && mounted) {

          setState(() {
            _currentLandmarks = landmarks;
            _predictedSign = result.$1;
            _confidence = result.$2;
          });
        }
      } else {
        if (mounted) {
          setState(() => _currentLandmarks = null);
        }
      }
    } catch (_) {}
    _isProcessing = false;
  }
  Uint8List _convertYUV420toImageBytes(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final img = Uint8List(width * height * 4);
      final Plane yPlane = image.planes[0];
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 1;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int yIndex = y * yPlane.bytesPerRow + x;
          final int uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
          final int yValue = yPlane.bytes[yIndex];
          final int uValue = uPlane.bytes[uvIndex];
          final int vValue = vPlane.bytes[uvIndex];
          final int r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
          final int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round().clamp(0, 255);
          final int b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);
          final int index = (y * width + x) * 4;
          img[index] = r;
          img[index + 1] = g;
          img[index + 2] = b;
          img[index + 3] = 255;
        }
      }
      return img;
    } catch (e) {
      return Uint8List(image.width * image.height * 4);
    }
  }
  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _handLandmarkerService.dispose();
    _signClassifierService.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Freedom Mode')),
      body: Stack(
        children: [
          !_isInitialized
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        CameraPreviewWidget(
                          controller: _cameraController!,
                          overlay: _currentLandmarks != null
                              ? CustomPaint(
                                  painter: HandPainter(landmarks: _currentLandmarks, imageSize: _cameraController!.value.previewSize!),
                                )
                              : null,
                        ),
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _currentLandmarks != null 
                                  ? 'Hand Detected ✓\n${(_confidence * 100).toStringAsFixed(0)}% Confident'
                                  : 'No Hand Detected',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(24),
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      children: [
                        if (_currentLandmarks != null) ...[
                          Text(_predictedSign, style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('${(_confidence * 100).toStringAsFixed(1)}% Confident', style: TextStyle(fontSize: 18, color: _confidence > 0.7 ? Colors.green : Colors.orange)),
                        ] else
                          const Text('Show Your Hand To The Camera', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  ),
                ],
              ),
          if (_showTutorial)
            TutorialOverlay(
              modeKey: 'freedom',
              title: 'Freedom Mode',
              description: 'Explore Sign Language Freely! Make Any Hand Sign & See It Recognized Instantly!',
              icon: Icons.explore,
              steps: [
                'Hold Your Hand In Front Of The Camera',
                'Make Any ASL Letter Sign',
                'See The Detected Letter & Confidence Below',
                'Green Skeleton Shows Hand Tracking',
              ],
              onDismiss: () => setState(() => _showTutorial = false),
            ),
        ],
      ),
    );
  }
}