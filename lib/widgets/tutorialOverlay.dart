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
      color: Colors.black.withValues(alpha: 0.9),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.5)),
                  ),
                  child: Icon(icon, size: 64, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: 32),
                Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(description, style: TextStyle(fontSize: 16, color: Colors.grey[300], height: 1.5), textAlign: TextAlign.center),
                const SizedBox(height: 40),
                ...steps.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(child: Text('${entry.key + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 16, color: Colors.white, height: 1.3))),
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
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Got It!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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