import 'package:hive_flutter/hive_flutter.dart';
import '../models/userModel.dart';
import '../models/statsModel.dart';
class CacheService {
  static const String userBoxName = 'userBox';
  static const String statsBoxName = 'statsBox';
  static const String settingsBoxName = 'settingsBox';
  Future<void> initialize() async {
    await Hive.initFlutter();
    Hive.registerAdapter(UserModelAdapter());
    Hive.registerAdapter(StatsModelAdapter());
    await Hive.openBox<UserModel>(userBoxName);
    await Hive.openBox<StatsModel>(statsBoxName);
    await Hive.openBox(settingsBoxName);
  }
  UserModel? getUser() {
    final box = Hive.box<UserModel>(userBoxName);
    return box.get('currentUser');
  }
  Future<void> saveUser(String name) async {
    final box = Hive.box<UserModel>(userBoxName);
    final user = UserModel(name: name, createdAt: DateTime.now());
    await box.put('currentUser', user);
  }
  StatsModel? getStats() {
    final box = Hive.box<StatsModel>(statsBoxName);
    return box.get('stats');
  }
  Future<void> saveStats(StatsModel stats) async {
    final box = Hive.box<StatsModel>(statsBoxName);
    await box.put('stats', stats);
  }
  Future<void> updateBestScore(int score) async {
    final stats = getStats() ?? StatsModel(bestScore: 0, currentStreak: 0, lastPracticeDate: DateTime.now(), learnedSigns: []);
    if (score > stats.bestScore) {
      stats.bestScore = score;
      await saveStats(stats);
    }
  }
  Future<void> updateStreak() async {
    final stats = getStats() ?? StatsModel(bestScore: 0, currentStreak: 0, lastPracticeDate: DateTime.now(), learnedSigns: []);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(stats.lastPracticeDate.year, stats.lastPracticeDate.month, stats.lastPracticeDate.day);
    final diff = today.difference(lastDate).inDays;
    if (stats.currentStreak == 0) {
      stats.currentStreak = 1;
    } else if (diff == 0) {
      return;
    } else if (diff == 1) {
      stats.currentStreak++;
    } else {
      stats.currentStreak = 1;
    }
    stats.lastPracticeDate = now;
    await saveStats(stats);
  }
  bool hasCompletedDailyChallengeToday() {
    final box = Hive.box(settingsBoxName);
    final lastCompleted = box.get('lastDailyChallengeDate');
    if (lastCompleted == null) return false;
    final lastDate = DateTime.parse(lastCompleted as String);
    final today = DateTime.now();
    return lastDate.year == today.year && lastDate.month == today.month && lastDate.day == today.day;
  }
  Future<void> markDailyChallengeCompleted() async {
    final box = Hive.box(settingsBoxName);
    await box.put('lastDailyChallengeDate', DateTime.now().toIso8601String());
  }
  Future<void> addLearnedSign(String sign) async {
    final stats = getStats() ?? StatsModel(bestScore: 0, currentStreak: 0, lastPracticeDate: DateTime.now(), learnedSigns: []);
    if (!stats.learnedSigns.contains(sign)) {
      stats.learnedSigns.add(sign);
      await saveStats(stats);
    }
  }
  bool isDarkMode() {
    final box = Hive.box(settingsBoxName);
    return box.get('darkMode', defaultValue: false);
  }
  Future<void> setDarkMode(bool value) async {
    final box = Hive.box(settingsBoxName);
    await box.put('darkMode', value);
  }
  Future<void> resetProgress() async {
    final statsBox = Hive.box<StatsModel>(statsBoxName);
    await statsBox.clear();
    final settingsBox = Hive.box(settingsBoxName);
    await settingsBox.delete('lastDailyChallengeDate');
  }
}