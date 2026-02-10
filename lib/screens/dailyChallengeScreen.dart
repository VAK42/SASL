import 'dart:typed_data';
import 'dart:async';
import 'dart:math';
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
class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});
  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}
class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  CameraController? _cameraController;
  final _handLandmarkerService = HandLandmarkerService();
  final _signClassifierService = SignClassifierService();
  final _cacheService = CacheService();
  final _soundService = SoundService();
  bool _isInitialized = false;
  List<double>? _currentLandmarks;
  final List<String> _challengeLetters = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _isProcessing = false;
  bool _answered = false;
  bool _showSuccess = false;
  bool _showTutorial = false;
  @override
  void initState() {
    super.initState();
    _generateDailyChallenge();
    _showTutorial = !TutorialOverlay.hasSeenTutorial('daily');
    _initializeCamera();
  }
  void _generateDailyChallenge() {
    final seed = DateTime.now().year * 10000 + DateTime.now().month * 100 + DateTime.now().day;
    final random = Random(seed);
    final allLetters = List.generate(26, (i) => String.fromCharCode(65 + i));
    for (int i = 0; i < 10; i++) {
      _challengeLetters.add(allLetters[random.nextInt(allLetters.length)]);
    }
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
    if (_isProcessing || _answered) return;
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
          if (result.$1 == _challengeLetters[_currentIndex] && result.$2 > 0.7) {
            _onAnswer(true);
          }
        }
      } else if (mounted) {
        setState(() => _currentLandmarks = null);
      }
    } catch (e) {}
    _isProcessing = false;
  }
  void _onAnswer(bool correct) async {
    setState(() => _answered = true);
    if (correct) {
      _soundService.playCorrect();
      setState(() {
        _score++;
        _showSuccess = true;
      });
      await Future.delayed(const Duration(milliseconds: 500));
    }
    await Future.delayed(const Duration(seconds: 1));
    if (_currentIndex < _challengeLetters.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _showSuccess = false;
      });
    } else {
      setState(() => _showSuccess = false);
      _soundService.playComplete();
      _showResultsDialog();
    }
  }
  void _showResultsDialog() async {
    final percentage = (_score / _challengeLetters.length * 100).round();
    if (percentage == 100) {
      await _cacheService.updateStreak();
    }
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Daily Challenge Complete!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Score: $_score/${_challengeLetters.length}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text('$percentage%', style: TextStyle(fontSize: 32, color: percentage == 100 ? Colors.amber : Colors.blue)),
              if (percentage == 100) const Text('🔥 Streak Updated!', style: TextStyle(fontSize: 18)),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ),
      );
    }
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
      appBar: AppBar(title: Text('Daily Challenge - ${_currentIndex + 1}/10')),
      body: Stack(
        children: [
          !_isInitialized
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: CameraPreviewWidget(
                      controller: _cameraController!,
                      overlay: _currentLandmarks != null ? CustomPaint(painter: HandPainter(landmarks: _currentLandmarks, imageSize: _cameraController!.value.previewSize!)) : null,
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
                            const Icon(Icons.calendar_today, color: Colors.amber),
                            const SizedBox(width: 8),
                            Text('Today: ${DateTime.now().month}/${DateTime.now().day}', style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(_challengeLetters[_currentIndex], style: const TextStyle(fontSize: 96, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Score: $_score/${_currentIndex + 1}', style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _answered ? null : () => _onAnswer(false), child: const Text('Skip')),
                      ],
                    ),
                  ),
                ],
              ),
          if (_showSuccess)
            SuccessAnimation(onComplete: () {}),
          if (_showTutorial)
            TutorialOverlay(
              modeKey: 'daily',
              title: 'Daily Challenge',
              description: 'A Unique Set Of 10 Signs Generated Each Day!',
              icon: Icons.calendar_today,
              steps: [
                'Same Challenge For Everyone Today',
                'Sign Each Letter As It Appears',
                'Skip If You\'re Unsure',
                'Get 100% To Keep Your Streak!',
              ],
              onDismiss: () => setState(() => _showTutorial = false),
            ),
        ],
      ),
    );
  }
}