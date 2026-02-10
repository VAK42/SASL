import 'package:flutter/material.dart';
class StreakIndicator extends StatelessWidget {
  final int streakDays;
  const StreakIndicator({super.key, required this.streakDays});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.orange.shade700, Colors.deepOrange.shade900]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, color: Colors.white, size: 32),
          const SizedBox(width: 8),
          Text('$streakDays Day Streak', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}