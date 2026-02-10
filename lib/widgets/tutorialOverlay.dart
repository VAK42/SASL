import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
class TutorialOverlay extends StatelessWidget {
  final String modeKey;
  final String title;
  final String description;
  final IconData icon;
  final List<String> steps;
  final VoidCallback onDismiss;
  const TutorialOverlay({
    super.key,
    required this.modeKey,
    required this.title,
    required this.description,
    required this.icon,
    required this.steps,
    required this.onDismiss,
  });
  static bool hasSeenTutorial(String modeKey) {
    final box = Hive.box('settingsBox');
    final key = 'tutorial${modeKey[0].toUpperCase()}${modeKey.substring(1)}';
    return box.get(key, defaultValue: false);
  }
  static Future<void> markTutorialSeen(String modeKey) async {
    final box = Hive.box('settingsBox');
    final key = 'tutorial${modeKey[0].toUpperCase()}${modeKey.substring(1)}';
    await box.put(key, true);
  }
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 64, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.8)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ...steps.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await markTutorialSeen(modeKey);
                      onDismiss();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Got It!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}