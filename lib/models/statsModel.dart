import 'package:hive/hive.dart';
part 'statsModel.g.dart';
@HiveType(typeId: 1)
class StatsModel extends HiveObject {
  @HiveField(0)
  int bestScore;
  @HiveField(1)
  int currentStreak;
  @HiveField(2)
  DateTime lastPracticeDate;
  @HiveField(3)
  List<String> learnedSigns;
  StatsModel({required this.bestScore, required this.currentStreak, required this.lastPracticeDate, required this.learnedSigns});
}