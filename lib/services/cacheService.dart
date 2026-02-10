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
    final lastDate = stats.lastPracticeDate;
    final diff = now.difference(lastDate).inDays;
    if (diff == 1) {
      stats.currentStreak++;
    } else if (diff > 1) {
      stats.currentStreak = 1;
    }
    stats.lastPracticeDate = now;
    await saveStats(stats);
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
  }
}