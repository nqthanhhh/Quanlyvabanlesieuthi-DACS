import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 1)
class User extends HiveObject {
  int? userId;

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
    this.userId,
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

  static int? _toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: _toNullableInt(json['user_id'] ?? json['id']),
      email: (json['email'] ?? '').toString(),
      password: (json['password'] ?? '').toString(),
      role: (json['role_name'] ?? json['role'] ?? '').toString(),
      fullName: (json['full_name'] ?? json['fullName'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'user_id': userId,
      'email': email,
      'phone': phone.isEmpty ? null : phone,
      'password': password,
      'address': address.isEmpty ? null : address,
      'role': role,
    };
  }
}
