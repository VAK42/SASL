import 'dart:math' as math;
class FeatureExtractor {
  static List<double> extractRawFeatures(List<double> landmarks) {
    final points = List.generate(21, (i) => [landmarks[i*3], landmarks[i*3+1], landmarks[i*3+2]]);
    final wrist = [...points[0]];
    final centered = points.map((p) => [p[0]-wrist[0], p[1]-wrist[1], p[2]-wrist[2]]).toList();
    double maxDist = 0;
    for (int i = 1; i < 21; i++) {
      final dist = math.sqrt(centered[i][0]*centered[i][0] + centered[i][1]*centered[i][1]);
      if (dist > maxDist) maxDist = dist;
    }
    maxDist = maxDist + 1e-6;
    for (var p in centered) {
      p[0] /= maxDist;
      p[1] /= maxDist;
    }
    return centered.expand((p) => p).toList();
  }
  static List<double> extractAngleFeatures(List<double> landmarks) {
    final points = List.generate(21, (i) => [landmarks[i*3], landmarks[i*3+1]]);
    final wrist = points[0];
    double maxDist = 0;
    for (int i = 1; i < 21; i++) {
      final dist = math.sqrt(math.pow(points[i][0]-wrist[0], 2) + math.pow(points[i][1]-wrist[1], 2));
      if (dist > maxDist) maxDist = dist;
    }
    maxDist = maxDist + 1e-6;
    final normPoints = points.map((p) => [(p[0]-wrist[0])/maxDist, (p[1]-wrist[1])/maxDist]).toList();
    double calcAngle(List<double> p1, List<double> p2, List<double> p3) {
      final v1 = [p1[0]-p2[0], p1[1]-p2[1]];
      final v2 = [p3[0]-p2[0], p3[1]-p2[1]];
      final dot = v1[0]*v2[0] + v1[1]*v2[1];
      final norm1 = math.sqrt(v1[0]*v1[0] + v1[1]*v1[1]);
      final norm2 = math.sqrt(v2[0]*v2[0] + v2[1]*v2[1]);
      final cos = dot / (norm1 * norm2 + 1e-6);
      return math.acos(cos.clamp(-1.0, 1.0)) / math.pi;
    }
    final fingerJoints = [[0,1,2,3,4], [0,5,6,7,8], [0,9,10,11,12], [0,13,14,15,16], [0,17,18,19,20]];
    final angles = <double>[];
    for (var finger in fingerJoints) {
      for (int i = 0; i < finger.length - 2; i++) {
        angles.add(calcAngle(normPoints[finger[i]], normPoints[finger[i+1]], normPoints[finger[i+2]]));
      }
    }
    for (int i = 0; i < fingerJoints.length; i++) {
      for (int j = i+1; j < fingerJoints.length; j++) {
        final tip1 = normPoints[fingerJoints[i].last];
        final tip2 = normPoints[fingerJoints[j].last];
        final dist = math.sqrt(math.pow(tip1[0]-tip2[0], 2) + math.pow(tip1[1]-tip2[1], 2));
        angles.add(dist);
      }
    }
    return angles;
  }
  static List<double> extractDistanceFeatures(List<double> landmarks) {
    final points = List.generate(21, (i) => [landmarks[i*3], landmarks[i*3+1]]);
    final wrist = points[0];
    double maxDist = 0;
    for (int i = 1; i < 21; i++) {
      final dist = math.sqrt(math.pow(points[i][0]-wrist[0], 2) + math.pow(points[i][1]-wrist[1], 2));
      if (dist > maxDist) maxDist = dist;
    }
    maxDist = maxDist + 1e-6;
    final normPoints = points.map((p) => [(p[0]-wrist[0])/maxDist, (p[1]-wrist[1])/maxDist]).toList();
    final keyPoints = [0, 4, 8, 12, 16, 20];
    final distances = <double>[];
    for (int i = 0; i < keyPoints.length; i++) {
      for (int j = i+1; j < keyPoints.length; j++) {
        final p1 = normPoints[keyPoints[i]];
        final p2 = normPoints[keyPoints[j]];
        final dist = math.sqrt(math.pow(p1[0]-p2[0], 2) + math.pow(p1[1]-p2[1], 2));
        distances.add(dist);
      }
    }
    final fingerBases = [1, 5, 9, 13, 17];
    final fingerTips = [4, 8, 12, 16, 20];
    for (int i = 0; i < 5; i++) {
      final base = normPoints[fingerBases[i]];
      final tip = normPoints[fingerTips[i]];
      final dist = math.sqrt(math.pow(tip[0]-base[0], 2) + math.pow(tip[1]-base[1], 2));
      distances.add(dist);
    }
    for (var tipIdx in fingerTips) {
      distances.add(normPoints[tipIdx][1]);
    }
    return distances;
  }
  static List<double> extractCombinedFeatures(List<double> landmarks) {
    final raw = extractRawFeatures(landmarks);
    final angles = extractAngleFeatures(landmarks);
    final distances = extractDistanceFeatures(landmarks);
    return [...raw, ...angles, ...distances];
  }
}