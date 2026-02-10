import 'package:flutter/material.dart';
class HandPainter extends CustomPainter {
  final List<double>? landmarks;
  final Size imageSize;
  HandPainter({this.landmarks, required this.imageSize});
  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks == null || landmarks!.length != 63) return;
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final points = <Offset>[];
    for (int i = 0; i < 21; i++) {
      final x = landmarks![i * 3 + 1] * size.width;
      final y = landmarks![i * 3] * size.height;
      points.add(Offset(x, y));
    }
    for (var point in points) {
      canvas.drawCircle(point, 5, paint);
    }
    final connections = [
      [0,1],[1,2],[2,3],[3,4],
      [0,5],[5,6],[6,7],[7,8],
      [0,9],[9,10],[10,11],[11,12],
      [0,13],[13,14],[14,15],[15,16],
      [0,17],[17,18],[18,19],[19,20],
      [5,9],[9,13],[13,17]
    ];
    for (var conn in connections) {
      canvas.drawLine(points[conn[0]], points[conn[1]], linePaint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}