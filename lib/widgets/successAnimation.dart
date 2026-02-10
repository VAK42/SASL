import 'package:flutter/material.dart';
import 'dart:math';
class SuccessAnimation extends StatefulWidget {
  final VoidCallback? onComplete;
  const SuccessAnimation({super.key, this.onComplete});
  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();
}
class _SuccessAnimationState extends State<SuccessAnimation> with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _particleController;
  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;
  final List<_Particle> _particles = [];
  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _particleController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _checkScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );
    _checkOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _checkController, curve: const Interval(0.7, 1.0)),
    );
    final random = Random();
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        angle: random.nextDouble() * 2 * pi,
        speed: 50 + random.nextDouble() * 150,
        size: 4 + random.nextDouble() * 8,
        color: [
          Colors.greenAccent,
          Colors.amber,
          Colors.lightBlueAccent,
          Colors.pinkAccent,
          Colors.orangeAccent,
        ][random.nextInt(5)],
      ));
    }
    _checkController.forward();
    _particleController.forward();
    Future.delayed(const Duration(milliseconds: 1200), () {
      widget.onComplete?.call();
    });
  }
  @override
  void dispose() {
    _checkController.dispose();
    _particleController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_checkController, _particleController]),
      builder: (context, child) {
        return CustomPaint(
          painter: _SuccessPainter(
            checkProgress: _checkScale.value,
            checkOpacity: _checkOpacity.value,
            particleProgress: _particleController.value,
            particles: _particles,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}
class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  _Particle({required this.angle, required this.speed, required this.size, required this.color});
}
class _SuccessPainter extends CustomPainter {
  final double checkProgress;
  final double checkOpacity;
  final double particleProgress;
  final List<_Particle> particles;
  _SuccessPainter({
    required this.checkProgress,
    required this.checkOpacity,
    required this.particleProgress,
    required this.particles,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (final p in particles) {
      final dx = cos(p.angle) * p.speed * particleProgress;
      final dy = sin(p.angle) * p.speed * particleProgress;
      final opacity = (1 - particleProgress).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center + Offset(dx, dy), p.size * (1 - particleProgress * 0.5), paint);
    }
    if (checkProgress > 0) {
      final circlePaint = Paint()
        ..color = Colors.green.withValues(alpha: checkOpacity * 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 40 * checkProgress, circlePaint);
      final checkPaint = Paint()
        ..color = Colors.white.withValues(alpha: checkOpacity)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path();
      path.moveTo(center.dx - 15 * checkProgress, center.dy);
      path.lineTo(center.dx - 5 * checkProgress, center.dy + 12 * checkProgress);
      path.lineTo(center.dx + 15 * checkProgress, center.dy - 10 * checkProgress);
      canvas.drawPath(path, checkPaint);
    }
  }
  @override
  bool shouldRepaint(covariant _SuccessPainter oldDelegate) => true;
}