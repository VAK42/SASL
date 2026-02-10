import 'package:flutter/material.dart';
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
    final user = cacheService.getUser();
    final stats = cacheService.getStats() ?? StatsModel(bestScore: 0, currentStreak: 0, lastPracticeDate: DateTime.now(), learnedSigns: []);
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome Back, ${user?.name ?? "User"}!'),
        actions: [IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: StreakIndicator(streakDays: stats.currentStreak)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _statCard('Best Score', '${stats.bestScore}', Icons.emoji_events)),
                const SizedBox(width: 16),
                Expanded(child: _statCard('Signs Learned', '${stats.learnedSigns.length}', Icons.school)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Modes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _modeCard('Dictionary', 'View All Signs A-Z', Icons.book, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DictionaryScreen()))),
            _modeCard('Freedom Mode', 'Explore Hand Sign Recognition', Icons.explore, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FreedomModeScreen()))),
            _modeCard('Practice Mode', 'Learn Signs Step By Step', Icons.fitness_center, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PracticeModeScreen()))),
            _modeCard('Test Mode', 'Test Your Knowledge With Scoring', Icons.quiz, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TestModeScreen()))),
            _modeCard('Speed Challenge', '60-Second Speed Test', Icons.timer, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpeedChallengeScreen()))),
            _modeCard('Word Spelling', 'Spell Words Letter By Letter', Icons.spellcheck, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WordSpellingScreen()))),
            _modeCard('Daily Challenge', 'Unique Daily Challenges', Icons.calendar_today, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyChallengeScreen()))),
          ],
        ),
      ),
    );
  }
  Widget _statCard(String title, String value, IconData icon) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
  Widget _modeCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 40, color: Theme.of(context).primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}