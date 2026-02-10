import 'package:hive/hive.dart';
part 'userModel.g.dart';
@HiveType(typeId: 0)
class UserModel extends HiveObject {
  @HiveField(0)
  String name;
  @HiveField(1)
  DateTime createdAt;
  UserModel({required this.name, required this.createdAt});
}