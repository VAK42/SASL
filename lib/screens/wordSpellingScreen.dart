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
          final expectedLetter = _currentWord[_currentLetterIndex];
          if (result.$1 == expectedLetter && result.$2 > 0.7) {
            _soundService.playCorrect();
            setState(() {
              _spelledSoFar += expectedLetter;
              _currentLetterIndex++;
              _showSuccess = true;
            });
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) setState(() => _showSuccess = false);
            });
            if (_currentLetterIndex >= _currentWord.length) {
              await Future.delayed(const Duration(milliseconds: 500));
              _nextWord();
            }
          }
        }
      } else if (mounted) {
        setState(() => _currentLandmarks = null);
      }
    } catch (e) {}
    _isProcessing = false;
  }
  void _nextWord() {
    setState(() {
      _wordsCompleted++;
      if (_wordsCompleted >= 5) {
        _soundService.playComplete();
        _showCompletionDialog();
      } else {
        _currentWord = _words[Random().nextInt(_words.length)];
        _currentLetterIndex = 0;
        _spelledSoFar = '';
      }
    });
  }
  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Great Job!'),
        content: const Text('You Spelled 5 Words Correctly!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _currentWord = _words[Random().nextInt(_words.length)];
                _currentLetterIndex = 0;
                _spelledSoFar = '';
                _wordsCompleted = 0;
              });
            },
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
    return Scaffold(
      appBar: AppBar(title: Text('Word Spelling - ${_wordsCompleted + 1}/5')),
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
                        const Text('Spell This Word:', style: TextStyle(fontSize: 18)),
                        const SizedBox(height: 8),
                        Text(_currentWord, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_currentWord.length, (i) {
                            final isCompleted = i < _spelledSoFar.length;
                            final isCurrent = i == _currentLetterIndex;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 40,
                                height: 50,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isCurrent ? Colors.amber : Colors.blue,
                                    width: isCurrent ? 3 : 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: isCompleted ? Colors.green.shade100 : null,
                                ),
                                child: Center(
                                  child: Text(
                                    isCompleted ? _spelledSoFar[i] : '',
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                        if (_currentLetterIndex < _currentWord.length)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Next: ${_currentWord[_currentLetterIndex]}', style: const TextStyle(fontSize: 32, color: Colors.blue)),
                              const SizedBox(width: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/images/signs/${_currentWord[_currentLetterIndex].toLowerCase()}.png',
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.contain,
                                  errorBuilder: (ctx, e, s) => const SizedBox(),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
          if (_showSuccess)
            SuccessAnimation(onComplete: () {}),
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