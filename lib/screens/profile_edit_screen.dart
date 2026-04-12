import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/db_service.dart';
import '../models/user.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _gender = 'male';
  DateTime? _startDate;
  String? _avatarPath;

  User? _user;

  @override
  void initState() {
    super.initState();
    final settings = DBService.settings();
    final email = settings.get('current_user_email') as String?;
    if (email != null) {
      _user = DBService.users().values.cast<User?>().firstWhere(
        (u) => u?.email == email,
        orElse: () => null,
      );
      if (_user != null) {
        _fullNameCtrl.text = _user!.fullName;
        _phoneCtrl.text = _user!.phone;
        _addressCtrl.text = _user!.address;
        _gender = _user!.gender.isNotEmpty ? _user!.gender : _gender;
        _startDate = _user!.startDate;
        _avatarPath = _user!.avatarPath;
      }
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
    );
    if (file != null) {
      setState(() => _avatarPath = file.path);
    }
  }

  Future<void> _save() async {
    if (_user == null) return;
    if (!_formKey.currentState!.validate()) return;
    _user!.fullName = _fullNameCtrl.text.trim();
    _user!.phone = _phoneCtrl.text.trim();
    _user!.address = _addressCtrl.text.trim();
    _user!.gender = _gender;
    _user!.startDate = _startDate;
    _user!.avatarPath = _avatarPath;
    await _user!.save();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(1980),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa thông tin')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: _avatarPath != null
                            ? FileImage(File(_avatarPath!))
                            : null,
                        child: _avatarPath == null
                            ? const Icon(Icons.person, size: 48)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: _pickAvatar,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fullNameCtrl,
                  decoration: const InputDecoration(labelText: 'Họ tên'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Vui lòng nhập họ tên'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(labelText: 'Địa chỉ'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(labelText: 'Giới tính'),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Nam')),
                    DropdownMenuItem(value: 'female', child: Text('Nữ')),
                    DropdownMenuItem(value: 'other', child: Text('Khác')),
                  ],
                  onChanged: (v) => setState(() => _gender = v ?? 'male'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Ngày bắt đầu',
                    hintText: _startDate == null
                        ? 'Chọn ngày'
                        : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
                  ),
                  onTap: _pickStartDate,
                ),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: _save, child: const Text('Lưu')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
