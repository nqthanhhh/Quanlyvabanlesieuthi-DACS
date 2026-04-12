import 'dart:io';

import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../models/user.dart';
import 'profile_edit_screen.dart';

class ProfileViewScreen extends StatefulWidget {
  const ProfileViewScreen({super.key});

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  User? _user;

  void _loadUser() {
    final settings = DBService.settings();
    final email = settings.get('current_user_email') as String?;
    if (email != null) {
      final users = DBService.users();
      _user = users.values.cast<User?>().firstWhere(
        (u) => u?.email == email,
        orElse: () => null,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _openEditor() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileEditScreen()));
    setState(() => _loadUser());
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thông tin cá nhân')),
        body: const Center(child: Text('Không tìm thấy thông tin người dùng')),
      );
    }

    final user = _user!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin cá nhân'),
        actions: [
          IconButton(onPressed: _openEditor, icon: const Icon(Icons.edit)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: user.avatarPath != null
                          ? FileImage(File(user.avatarPath!))
                          : null,
                      child: user.avatarPath == null
                          ? const Icon(Icons.person, size: 48)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.fullName.isNotEmpty ? user.fullName : user.email,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.role == 'owner' ? 'Chủ cửa hàng' : 'Nhân viên',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              _infoRow('Email', user.email),
              _infoRow('Họ tên', user.fullName),
              _infoRow(
                'Năm sinh',
                user.birthYear == 0 ? '' : user.birthYear.toString(),
              ),
              _infoRow('Số điện thoại', user.phone),
              _infoRow('Địa chỉ', user.address),
              _infoRow('Giới tính', user.gender),
              _infoRow(
                'Ngày bắt đầu',
                user.startDate == null
                    ? ''
                    : '${user.startDate!.day}/${user.startDate!.month}/${user.startDate!.year}',
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(flex: 3, child: Text(value)),
      ],
    ),
  );
}
