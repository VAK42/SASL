import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/handLandmarkerService.dart';
import '../services/signClassifierService.dart';
import '../services/cacheService.dart';
import '../services/soundService.dart';
import '../widgets/successAnimation.dart';
import '../widgets/tutorialOverlay.dart';
import '../widgets/cameraPreview.dart';
import '../widgets/handPainter.dart';
class PracticeModeScreen extends StatefulWidget {
  const PracticeModeScreen({super.key});
  @override
  State<PracticeModeScreen> createState() => _PracticeModeScreenState();
}
class _PracticeModeScreenState extends State<PracticeModeScreen> {
  CameraController? _cameraController;
  final _handLandmarkerService = HandLandmarkerService();
  final _signClassifierService = SignClassifierService();
  final _cacheService = CacheService();
  final _soundService = SoundService();
  bool _isInitialized = false;
  List<double>? _currentLandmarks;
  final _letters = List.generate(26, (i) => String.fromCharCode(65 + i));
  int _currentIndex = 0;
  String _feedback = '';
  Color _feedbackColor = Colors.grey;
  bool _isProcessing = false;
  int _correctCount = 0;
  bool _showSuccess = false;
  bool _showTutorial = false;
  @override
  void initState() {
    super.initState();
    _showTutorial = !TutorialOverlay.hasSeenTutorial('practice');
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
    } catch (e) {}
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
          setState(() => _currentLandmarks = landmarks);
          if (result.$1 == _letters[_currentIndex] && result.$2 > 0.7) {
            _onCorrectSign();
          }
        }
      } else if (mounted) {
        setState(() => _currentLandmarks = null);
      }
    } catch (e) {}
    _isProcessing = false;
  }
  void _onCorrectSign() async {
    _soundService.playCorrect();
    setState(() {
      _feedback = 'Correct! ✓';
      _feedbackColor = Colors.green;
      _correctCount++;
      _showSuccess = true;
    });
    await _cacheService.addLearnedSign(_letters[_currentIndex]);
    await Future.delayed(const Duration(seconds: 1));
    if (_currentIndex < _letters.length - 1) {
      setState(() {
        _currentIndex++;
        _feedback = '';
        _showSuccess = false;
      });
    } else {
      setState(() => _showSuccess = false);
      _soundService.playComplete();
      _showCompletionDialog();
    }
  }
  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Practice Complete!'),
        content: Text('You Completed All 26 Letters!\nCorrect: $_correctCount/26'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _currentIndex = 0;
                _correctCount = 0;
                _feedback = '';
              });
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }
  Uint8List _convertYUV420toImageBytes(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
    final imgBuffer = Uint8List(width * height * 4);
    int bufferIndex = 0;
    for (int y = 0; y < height; y++) {
      int pY = y * width;
      int pUV = (y >> 1) * uvRowStride;
      for (int x = 0; x < width; x++) {
        int uvIndex = pUV + (x >> 1) * uvPixelStride;
        int yValue = image.planes[0].bytes[pY];
        int uValue = image.planes[1].bytes[uvIndex];
        int vValue = image.planes[2].bytes[uvIndex];
        int r = (yValue + vValue * 1436 / 1024 - 179).clamp(0, 255).toInt();
        int g = (yValue - uValue * 46549 / 131072 + 44 - vValue * 93604 / 131072 + 91).clamp(0, 255).toInt();
        int b = (yValue + uValue * 1814 / 1024 - 227).clamp(0, 255).toInt();
        imgBuffer[bufferIndex++] = r;
        imgBuffer[bufferIndex++] = g;
        imgBuffer[bufferIndex++] = b;
        imgBuffer[bufferIndex++] = 255;
        pY++;
      }
    }
    return imgBuffer;
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
      appBar: AppBar(title: Text('Practice Mode - ${_currentIndex + 1}/26')),
      body: Stack(
        children: [
          !_isInitialized
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: CameraPreviewWidget(
                      controller: _cameraController!,
                      overlay: _currentLandmarks != null
                          ? CustomPaint(painter: HandPainter(landmarks: _currentLandmarks, imageSize: _cameraController!.value.previewSize!))
                          : null,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(24),
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Show This Sign:', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/images/signs/${_letters[_currentIndex].toLowerCase()}.png',
                                width: 50,
                                height: 50,
                                fit: BoxFit.contain,
                                errorBuilder: (ctx, e, s) => const SizedBox(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(_letters[_currentIndex], style: const TextStyle(fontSize: 96, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        if (_feedback.isNotEmpty) Text(_feedback, style: TextStyle(fontSize: 24, color: _feedbackColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
          if (_showSuccess)
            SuccessAnimation(onComplete: () {}),
          if (_showTutorial)
            TutorialOverlay(
              modeKey: 'practice',
              title: 'Practice Mode',
              description: 'Learn Each Letter Step By Step From A To Z!',
              icon: Icons.fitness_center,
              steps: [
                'A Letter Will Be Displayed Below The Camera',
                'Make The Corresponding ASL Hand Sign',
                'Hold It Steady Until It\'s Recognized',
                'Move To The Next Letter Automatically',
              ],
              onDismiss: () => setState(() => _showTutorial = false),
            ),
        ],
      ),
    );
  }
}