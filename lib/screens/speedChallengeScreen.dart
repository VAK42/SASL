import 'dart:typed_data';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/handLandmarkerService.dart';
import '../services/signClassifierService.dart';
import '../services/soundService.dart';
import '../widgets/successAnimation.dart';
import '../widgets/tutorialOverlay.dart';
import '../widgets/cameraPreview.dart';
import '../widgets/handPainter.dart';
class SpeedChallengeScreen extends StatefulWidget {
  const SpeedChallengeScreen({super.key});
  @override
  State<SpeedChallengeScreen> createState() => _SpeedChallengeScreenState();
}
class _SpeedChallengeScreenState extends State<SpeedChallengeScreen> {
  CameraController? _cameraController;
  final _handLandmarkerService = HandLandmarkerService();
  final _signClassifierService = SignClassifierService();
  final _soundService = SoundService();
  bool _isInitialized = false;
  List<double>? _currentLandmarks;
  final _letters = List.generate(26, (i) => String.fromCharCode(65 + i));
  String _currentTarget = '';
  int _score = 0;
  int _timeLeft = 60;
  Timer? _timer;
  bool _isPlaying = false;
  bool _isProcessing = false;
  bool _showSuccess = false;
  bool _showTutorial = false;
  @override
  void initState() {
    super.initState();
    _showTutorial = !TutorialOverlay.hasSeenTutorial('speed');
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
      setState(() => _isInitialized = true);
    } catch (e) {}
  }
  void _startChallenge() {
    setState(() {
      _isPlaying = true;
      _score = 0;
      _timeLeft = 60;
      _currentTarget = _letters[Random().nextInt(_letters.length)];
    });
    _cameraController!.startImageStream(_processFrame);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        _endChallenge();
      }
    });
  }
  void _endChallenge() {
    _timer?.cancel();
    _cameraController?.stopImageStream();
    setState(() => _isPlaying = false);
    _soundService.playComplete();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Time\'s Up!'),
        content: Text('Final Score: $_score Signs In 60 Seconds!', style: const TextStyle(fontSize: 20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          TextButton(onPressed: () {
            Navigator.pop(ctx);
            _startChallenge();
          }, child: const Text('Retry')),
        ],
      ),
    );
  }
  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing || !_isPlaying) return;
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
          if (result.$1 == _currentTarget && result.$2 > 0.7) {
            _soundService.playCorrect();
            setState(() {
              _score++;
              _currentTarget = _letters[Random().nextInt(_letters.length)];
              _showSuccess = true;
            });
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) setState(() => _showSuccess = false);
            });
          }
        }
      } else if (mounted) {
        setState(() => _currentLandmarks = null);
      }
    } catch (e) {}
    _isProcessing = false;
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
    _timer?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _handLandmarkerService.dispose();
    _signClassifierService.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Speed Challenge')),
      body: Stack(
        children: [
          !_isInitialized
            ? const Center(child: CircularProgressIndicator())
            : !_isPlaying
                ? Center(
                    child: ElevatedButton(
                      onPressed: _startChallenge,
                      child: const Padding(padding: EdgeInsets.all(16), child: Text('Start 60s Challenge', style: TextStyle(fontSize: 20))),
                    ),
                  )
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Time: $_timeLeft s', style: TextStyle(fontSize: 24, color: _timeLeft <= 10 ? Colors.red : null)),
                                Text('Score: $_score', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(_currentTarget, style: const TextStyle(fontSize: 96, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
          if (_showSuccess)
            SuccessAnimation(onComplete: () {}),
          if (_showTutorial)
            TutorialOverlay(
              modeKey: 'speed',
              title: 'Speed Challenge',
              description: 'How Many Signs Can You Make In 60 Seconds?',
              icon: Icons.timer,
              steps: [
                'Press Start To Begin The 60-Second Timer',
                'Make The Shown Letter Sign As Fast As You Can',
                'A New Letter Appears After Each Correct Sign',
                'Try To Beat Your High Score!',
              ],
              onDismiss: () => setState(() => _showTutorial = false),
            ),
        ],
      ),
    );
  }
}