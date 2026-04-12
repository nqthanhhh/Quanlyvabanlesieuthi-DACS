import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 1)
class User extends HiveObject {
  @HiveField(0)
  String email;

  @HiveField(1)
  String password;

  @HiveField(2)
  String role; // 'owner' or 'staff'

  @HiveField(3)
  String fullName;

  @HiveField(4)
  int birthYear;

  @HiveField(5)
  String phone;

  @HiveField(6)
  String address;

  @HiveField(7)
  String gender;

  @HiveField(8)
  DateTime? startDate;

  @HiveField(9)
  String? avatarPath; // local file path or asset

  User({
    required this.email,
    required this.password,
    required this.role,
    this.fullName = '',
    this.birthYear = 0,
    this.phone = '',
    this.address = '',
    this.gender = '',
    this.startDate,
    this.avatarPath,
  });
}
