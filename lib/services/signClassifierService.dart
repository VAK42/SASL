import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'featureExtractor.dart';
class SignClassifierService {
  Interpreter? _interpreter;
  Map<String, dynamic>? _scalerParams;
  Map<int, String>? _labelMap;
  final List<int> _history = [];
  final List<double> _confidenceHistory = [];
  final int _historySize = 5;
  Future<bool> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/saslModel.tflite');
      final scalerJson = await rootBundle.loadString('assets/models/scalerParams.json');
      final scalerData = jsonDecode(scalerJson);
      _scalerParams = {
        'mean': List<double>.from(scalerData['mean']),
        'scale': List<double>.from(scalerData['scale']),
      };
      final labelJson = await rootBundle.loadString('assets/models/labelMap.json');
      final labelData = jsonDecode(labelJson);
      _labelMap = {};
      labelData.forEach((key, value) {
        _labelMap![int.parse(key)] = value as String;
      });
      return true;
    } catch (e) {
      return false;
    }
  }
  Future<(String, double)?> predict(List<double> landmarks) async {
    if (_interpreter == null || _labelMap == null) return null;
    try {
      final features = FeatureExtractor.extractCombinedFeatures(landmarks);
      final mean = _scalerParams!['mean'] as List<double>;
      final scale = _scalerParams!['scale'] as List<double>;
      final featuresScaled = List.generate(features.length, (i) => (features[i] - mean[i]) / scale[i]);
      final input = [featuresScaled];
      final output = List.filled(1, List.filled(26, 0.0)).map((e) => List<double>.filled(26, 0.0)).toList();
      _interpreter!.run(input, output);
      final probas = output[0];
      int predictedIdx = 0;
      double maxProba = probas[0];
      for (int i = 1; i < probas.length; i++) {
        if (probas[i] > maxProba) {
          maxProba = probas[i];
          predictedIdx = i;
        }
      }
      double confidence = maxProba;
      _history.add(predictedIdx);
      _confidenceHistory.add(confidence);
      if (_history.length > _historySize) {
        _history.removeAt(0);
        _confidenceHistory.removeAt(0);
      }
      if (_history.length >= 3) {
        final counts = <int, int>{};
        for (var idx in _history) {
          counts[idx] = (counts[idx] ?? 0) + 1;
        }
        int mostCommonIdx = predictedIdx;
        int maxCount = 0;
        counts.forEach((idx, count) {
          if (count > maxCount) {
            maxCount = count;
            mostCommonIdx = idx;
          }
        });
        if (maxCount >= 3) {
          predictedIdx = mostCommonIdx;
          final relevantConf = <double>[];
          for (int i = 0; i < _history.length; i++) {
            if (_history[i] == mostCommonIdx) {
              relevantConf.add(_confidenceHistory[i]);
            }
          }
          confidence = relevantConf.reduce((a, b) => a + b) / relevantConf.length;
        }
      }
      final label = _labelMap![predictedIdx] ?? "Unknown";
      return (label, confidence);
    } catch (e) {
      return null;
    }
  }
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}