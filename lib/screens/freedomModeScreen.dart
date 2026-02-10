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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final highlightColor = theme.primaryColor;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: Text('Freedom Mode', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: scaffoldColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Stack(
        children: [
          !_isInitialized
              ? Center(child: CircularProgressIndicator(color: highlightColor))
              : Column(
                  children: [
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _currentLandmarks != null ? Icons.check_circle : Icons.warning_amber_rounded,
                                        size: 14,
                                        color: _currentLandmarks != null ? Colors.greenAccent : Colors.amberAccent,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _currentLandmarks != null ? 'Hand Detected' : 'No Hand Detected',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: screenHeight * 0.35,
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_currentLandmarks != null) ...[
                            Text('Predicted Sign'.toUpperCase(), style: TextStyle(fontSize: 14, color: subTextColor, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                            const SizedBox(height: 8),
                            Text(
                              _predictedSign,
                              style: TextStyle(
                                fontSize: 96,
                                fontWeight: FontWeight.w900,
                                color: highlightColor,
                                height: 1.0,
                                shadows: [
                                  Shadow(
                                    color: highlightColor.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: (_confidence > 0.7 ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${(_confidence * 100).toStringAsFixed(1)}% Confidence',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _confidence > 0.7 ? Colors.green : Colors.orange,
                                ),
                              ),
                            ),
                          ] else ...[
                            Icon(Icons.back_hand_rounded, size: 64, color: subTextColor?.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text(
                              'Show Your Hand',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Position Your Hand In Front Of The Camera To Start Detecting Signs!',
                              style: TextStyle(fontSize: 14, color: subTextColor, height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                          ],
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
              icon: Icons.explore_outlined,
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