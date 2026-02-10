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
    if (_cacheService.hasCompletedDailyChallengeToday()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Challenge Complete!'),
              content: const Text('You\'ve Already Completed Today\'s Challenge! Come Back Tomorrow For A New One!'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      });
      return;
    }
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
    await _cacheService.markDailyChallengeCompleted();
    if (percentage == 100) {
      await _cacheService.updateStreak();
    }
    if (mounted) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final textColor = isDark ? Colors.white : Colors.black87;
      final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: cardColor,
          title: Text('Daily Challenge Complete!', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Score: $_score/${_challengeLetters.length}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 16),
              Text('$percentage%', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: percentage == 100 ? Colors.amber : Theme.of(context).primaryColor)),
              if (percentage == 100) ...[
                const SizedBox(height: 16),
                const Text('🔥 Streak Updated!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Done', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 16)),
            )
          ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.purpleAccent[100]! : Theme.of(context).primaryColor;
    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        backgroundColor: scaffoldColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text('Daily Challenge', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('${_currentIndex + 1}/10', style: TextStyle(color: subTextColor, fontSize: 16, fontWeight: FontWeight.w600))),
          ),
        ],
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
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: CameraPreviewWidget(
                          controller: _cameraController!,
                          overlay: _currentLandmarks != null ? CustomPaint(painter: HandPainter(landmarks: _currentLandmarks, imageSize: _cameraController!.value.previewSize!)) : null,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardColor,
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today_outlined, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Text('Today: ${DateTime.now().month}/${DateTime.now().day}', style: TextStyle(fontSize: 14, color: subTextColor, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                Text('Score', style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                                const SizedBox(height: 4),
                                Text('$_score/${_currentIndex + 1}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                              ],
                            ),
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: highlightColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: highlightColor.withOpacity(0.3)),
                              ),
                              child: Center(child: Text(_challengeLetters[_currentIndex], style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: highlightColor))),
                            ),
                            Column(
                              children: [
                                Text('Target', style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                                const SizedBox(height: 4),
                                Text('Sign It', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _answered ? null : () => _onAnswer(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: subTextColor,
                              side: BorderSide(color: borderColor),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Skip This Letter', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          if (_showSuccess) SuccessAnimation(onComplete: () {}),
          if (_showTutorial)
            TutorialOverlay(
              modeKey: 'daily',
              title: 'Daily Challenge',
              description: 'A Unique Set Of 10 Signs Generated Each Day!',
              icon: Icons.calendar_today,
              steps: ['Same Challenge For Everyone Today', 'Sign Each Letter As It Appears', 'Skip If You\'re Unsure', 'Get 100% To Keep Your Streak!'],
              onDismiss: () => setState(() => _showTutorial = false),
            ),
        ],
      ),
    );
  }
}