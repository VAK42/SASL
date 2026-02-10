import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/streakIndicator.dart';
import '../services/cacheService.dart';
import '../models/statsModel.dart';
import 'testModeScreen.dart';
import 'settingsScreen.dart';
import 'dictionaryScreen.dart';
import 'freedomModeScreen.dart';
import 'practiceModeScreen.dart';
import 'wordSpellingScreen.dart';
import 'speedChallengeScreen.dart';
import 'dailyChallengeScreen.dart';
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}
class _DashboardScreenState extends State<DashboardScreen> {
  final cacheService = CacheService();
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<StatsModel>('statsBox').listenable(),
      builder: (context, box, _) {
        final user = cacheService.getUser();
        final stats = cacheService.getStats() ?? StatsModel(bestScore: 0, currentStreak: 0, lastPracticeDate: DateTime.now(), learnedSigns: []);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            centerTitle: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome Back', style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.normal)),
                Text(user?.name ?? "User", style: TextStyle(fontSize: 20, color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.settings_outlined, color: Theme.of(context).iconTheme.color),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              )
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? Colors.orange.withOpacity(0.1) : Theme.of(context).cardColor,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Daily Streak', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const Icon(Icons.local_fire_department, color: Colors.orange),
                        ],
                      ),
                      const SizedBox(height: 16),
                      StreakIndicator(streakDays: stats.currentStreak),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _statCard('Best Score', '${stats.bestScore}', Icons.emoji_events_outlined, Colors.amber, isDark)),
                    const SizedBox(width: 16),
                    Expanded(child: _statCard('Signs Learned', '${stats.learnedSigns.length}', Icons.school_outlined, Colors.blue, isDark)),
                  ],
                ),
                const SizedBox(height: 32),
                const Text('Practice Modes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const SizedBox(height: 16),
                _modeCard('Dictionary', 'View All Signs A-Z', Icons.menu_book_outlined, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DictionaryScreen()))),
                _modeCard('Freedom Mode', 'Explore Hand Sign Recognition', Icons.back_hand_outlined, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FreedomModeScreen()))),
                _modeCard('Practice Mode', 'Learn Signs Step By Step', Icons.school_outlined, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PracticeModeScreen()))),
                _modeCard('Test Mode', 'Test Your Knowledge With Scoring', Icons.quiz_outlined, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TestModeScreen()))),
                _modeCard('Speed Challenge', '60-Second Speed Test', Icons.timer_outlined, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpeedChallengeScreen()))),
                _modeCard('Word Spelling', 'Spell Words Letter By Letter', Icons.spellcheck, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WordSpellingScreen()))),
                _modeCard('Daily Challenge', 'Unique Daily Challenges', Icons.calendar_today_outlined, isDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyChallengeScreen()))),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _statCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).cardColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
  Widget _modeCard(String title, String subtitle, IconData icon, bool isDark, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).cardColor,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 24, color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Theme.of(context).disabledColor),
            ],
          ),
        ),
      ),
    );
  }
}