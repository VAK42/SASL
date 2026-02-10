import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/handLandmarkerService.dart';
import '../services/signClassifierService.dart';
import '../services/cacheService.dart';
import '../services/soundService.dart';
import '../widgets/successAnimation.dart';
import '../widgets/tutorialOverlay.dart';
import '../widgets/cameraPreview.dart';
import '../widgets/handPainter.dart';
class TestModeScreen extends StatefulWidget {
  const TestModeScreen({super.key});
  @override
  State<TestModeScreen> createState() => _TestModeScreenState();
}
class _TestModeScreenState extends State<TestModeScreen> {
  CameraController? _cameraController;
  final _handLandmarkerService = HandLandmarkerService();
  final _signClassifierService = SignClassifierService();
  final _cacheService = CacheService();
  final _soundService = SoundService();
  bool _isInitialized = false;
  List<double>? _currentLandmarks;
  final _letters = List.generate(26, (i) => String.fromCharCode(65 + i));
  int _currentIndex = 0;
  int _score = 0;
  bool _isProcessing = false;
  bool _answered = false;
  bool _showSuccess = false;
  bool _showTutorial = false;
  @override
  void initState() {
    super.initState();
    _letters.shuffle();
    _showTutorial = !TutorialOverlay.hasSeenTutorial('test');
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
          if (result.$1 == _letters[_currentIndex] && result.$2 > 0.7) {
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
    if (_currentIndex < _letters.length - 1) {
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
    final percentage = (_score / _letters.length * 100).round();
    await _cacheService.updateBestScore(_score);
    if (mounted) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
      final textColor = isDark ? Colors.white : Colors.black87;
      final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: cardColor,
          title: Text('Test Complete!', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Score: $_score/${_letters.length}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 16),
              Text(
                '$percentage%', 
                style: TextStyle(
                  fontSize: 48, 
                  fontWeight: FontWeight.w900, 
                  color: percentage >= 70 ? Colors.green : Colors.orange
                )
              ),
              const SizedBox(height: 8),
              Text(
                percentage >= 90 ? 'Excellent!' : percentage >= 70 ? 'Great Job!' : 'Keep Practicing!',
                style: TextStyle(color: subTextColor, fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Done', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _currentIndex = 0;
                  _score = 0;
                  _answered = false;
                  _letters.shuffle();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
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
        title: Text('Test Mode', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: scaffoldColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentIndex + 1}/26',
                style: TextStyle(color: subTextColor, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
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
                                  color: highlightColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: highlightColor.withValues(alpha: 0.3)),
                                ),
                                child: Center(
                                  child: Text(
                                    _letters[_currentIndex], 
                                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: highlightColor)
                                  ),
                                ),
                              ),
                              Column(
                                children: [
                                  Text('Question', style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                                  const SizedBox(height: 4),
                                  Text('${_currentIndex + 1}/26', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
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
                              child: const Text('Skip Question', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
              modeKey: 'test',
              title: 'Test Mode',
              description: 'Test Your Knowledge! Letters Appear In Random Order!',
              icon: Icons.quiz_outlined,
              steps: [
                'A Random Letter Will Be Shown',
                'Make The Correct ASL Hand Sign',
                'Skip If You Don\'t Know The Sign',
                'See Your Final Score At The End',
              ],
              onDismiss: () => setState(() => _showTutorial = false),
            ),
        ],
      ),
    );
  }
}