import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../widgets/handPainter.dart';
import '../widgets/cameraPreview.dart';
import '../widgets/tutorialOverlay.dart';
import '../widgets/successAnimation.dart';
import '../services/handLandmarkerService.dart';
import '../services/signClassifierService.dart';
import '../services/soundService.dart';
class WordSpellingScreen extends StatefulWidget {
  const WordSpellingScreen({super.key});
  @override
  State<WordSpellingScreen> createState() => _WordSpellingScreenState();
}
class _WordSpellingScreenState extends State<WordSpellingScreen> {
  CameraController? _cameraController;
  final _handLandmarkerService = HandLandmarkerService();
  final _signClassifierService = SignClassifierService();
  final _soundService = SoundService();
  bool _isInitialized = false;
  List<double>? _currentLandmarks;
  final _words = ['CAT', 'DOG', 'BLUE', 'HELP', 'LOVE', 'HAND', 'SIGN', 'THINK', 'LEARN', 'FRIEND'];
  String _currentWord = '';
  int _currentLetterIndex = 0;
  String _spelledSoFar = '';
  bool _isProcessing = false;
  int _wordsCompleted = 0;
  bool _showSuccess = false;
  bool _showTutorial = false;
  bool _answered = false;
  @override
  void initState() {
    super.initState();
    _currentWord = _words[Random().nextInt(_words.length)];
    _showTutorial = !TutorialOverlay.hasSeenTutorial('wordspelling');
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
          final expectedLetter = _currentWord[_currentLetterIndex];
          if (result.$1 == expectedLetter && result.$2 > 0.7) {
            _onCorrectLetter(expectedLetter);
          }
        }
      } else if (mounted) {
        setState(() => _currentLandmarks = null);
      }
    } catch (e) {}
    _isProcessing = false;
  }
  void _onCorrectLetter(String letter) async {
    setState(() => _answered = true);
    _soundService.playCorrect();
    setState(() {
      _spelledSoFar += letter;
      _currentLetterIndex++;
      _showSuccess = true;
    });
    await Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showSuccess = false);
    });
    await Future.delayed(const Duration(milliseconds: 500));
    if (_currentLetterIndex >= _currentWord.length) {
      await Future.delayed(const Duration(milliseconds: 500));
      _nextWord();
    } else {
      if (mounted) setState(() => _answered = false);
    }
  }
  void _nextWord() {
    _wordsCompleted++;
    if (_wordsCompleted >= 5) {
      _soundService.playComplete();
      _showCompletionDialog();
    } else {
      String newWord;
      do {
        newWord = _words[Random().nextInt(_words.length)];
      } while (newWord == _currentWord && _words.length > 1);
      setState(() {
        _currentWord = newWord;
        _currentLetterIndex = 0;
        _spelledSoFar = '';
        _answered = false;
      });
    }
  }
  void _showCompletionDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text('Great Job!', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        content: Text('You Spelled 5 Words Correctly!', style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Done', style: TextStyle(color: theme.primaryColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _currentWord = _words[Random().nextInt(_words.length)];
                _currentLetterIndex = 0;
                _spelledSoFar = '';
                _wordsCompleted = 0;
                _answered = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
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
        title: Text('Word Spelling', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: scaffoldColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${min(_wordsCompleted + 1, 5)}/5',
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
                          Text('SPELL THIS WORD', style: TextStyle(fontSize: 14, color: subTextColor, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(_currentWord.length, (i) {
                              final isCompleted = i < _spelledSoFar.length;
                              final isCurrent = i == _currentLetterIndex;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 50,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: isCompleted ? Colors.green.withValues(alpha: 0.2) : (isDark ? Colors.grey[800] : Colors.grey[100]),
                                  border: Border.all(
                                    color: isCurrent 
                                        ? highlightColor 
                                        : isCompleted ? Colors.green : borderColor,
                                    width: isCurrent ? 3 : 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: isCurrent ? [
                                    BoxShadow(
                                      color: highlightColor.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ] : null,
                                ),
                                child: Center(
                                  child: Text(
                                    isCompleted ? _spelledSoFar[i] : _currentWord[i],
                                    style: TextStyle(
                                      fontSize: 28, 
                                      fontWeight: FontWeight.bold,
                                      color: isCompleted ? Colors.green : isCurrent ? highlightColor : subTextColor?.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const Spacer(),
                          if (_currentLetterIndex < _currentWord.length)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: highlightColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: highlightColor.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Sign: ${_currentWord[_currentLetterIndex]}', 
                                    style: TextStyle(fontSize: 20, color: highlightColor, fontWeight: FontWeight.bold)
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.black26 : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.asset(
                                        'assets/images/signs/${_currentWord[_currentLetterIndex].toLowerCase()}.png',
                                        width: 32,
                                        height: 32,
                                        fit: BoxFit.contain,
                                        errorBuilder: (ctx, e, s) => const SizedBox(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ],
                ),
          if (_showSuccess) SuccessAnimation(onComplete: () {}),
          if (_showTutorial)
            TutorialOverlay(
              modeKey: 'wordspelling',
              title: 'Word Spelling',
              description: 'Spell Complete Words Letter By Letter Using Sign Language!',
              icon: Icons.spellcheck,
              steps: [
                'A Word Will Be Shown To Spell',
                'Sign Each Letter One At A Time',
                'Letters Fill In As You Sign Correctly',
                'Complete 5 Words To Finish',
              ],
              onDismiss: () => setState(() => _showTutorial = false),
            ),
        ],
      ),
    );
  }
}