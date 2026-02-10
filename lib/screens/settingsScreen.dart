import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/cacheService.dart';
import '../services/soundService.dart';
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final cacheService = CacheService();
    final soundService = SoundService();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ValueListenableBuilder(
            valueListenable: Hive.box('settingsBox').listenable(),
            builder: (context, box, _) {
              final isDark = cacheService.isDarkMode();
              final isSoundOn = soundService.isSoundEnabled;
              return Column(
                children: [
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    subtitle: const Text('Toggle Dark Theme'),
                    value: isDark,
                    onChanged: (value) => cacheService.setDarkMode(value),
                  ),
                  SwitchListTile(
                    title: const Text('Sound Effects'),
                    subtitle: const Text('Play Sounds On Correct/Incorrect Signs'),
                    secondary: Icon(isSoundOn ? Icons.volume_up : Icons.volume_off),
                    value: isSoundOn,
                    onChanged: (value) => soundService.setSoundEnabled(value),
                  ),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Reset Progress'),
            subtitle: const Text('Clear All Stats & Learned Signs'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset Progress'),
                  content: const Text('Are You Sure You Want To Reset All Progress?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
                  ],
                ),
              );
              if (confirm == true) {
                await cacheService.resetProgress();
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress Reset')));
              }
            },
          ),
          const AboutListTile(applicationName: 'SASL', applicationVersion: '1.0.0', child: Text('About')),
        ],
      ),
    );
  }
}