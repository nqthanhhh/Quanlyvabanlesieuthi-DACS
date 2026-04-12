import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/db_service.dart';

class ProfileDetailsScreen extends StatefulWidget {
  final String email;
  final String password;
  final bool remember;

  const ProfileDetailsScreen({
    super.key,
    required this.email,
    required this.password,
    required this.remember,
  });

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameCtrl;
  late TextEditingController _birthYearCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _startDateCtrl;

  String _role = 'staff';
  String _gender = 'male';
  DateTime? _startDate;

  @override
  void initState() {
    super.initState();
    _fullNameCtrl = TextEditingController();
    _birthYearCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _startDateCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _birthYearCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _startDateCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(1980),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _startDateCtrl.text = _formatDate(picked);
      });
    }
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;

    final usersBox = DBService.users();
    final email = widget.email.trim();

    // check duplicate
    final exists = usersBox.values.any((u) => u.email == email);
    if (exists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Email đã tồn tại')));
      return;
    }

    final birthYear = int.tryParse(_birthYearCtrl.text.trim()) ?? 0;

    final user = User(
      email: email,
      password: widget.password,
      role: _role,
      fullName: _fullNameCtrl.text.trim(),
      birthYear: birthYear,
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      gender: _gender,
      startDate: _startDate,
    );

    usersBox.add(user);

    if (widget.remember) {
      final settings = DBService.settings();
      settings.put('remember_email', widget.email);
      settings.put('remember_pass', widget.password);
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Tạo tài khoản thành công')));

    // pop twice: close profile details and the register screen to go back to previous flow
    Navigator.of(context).pop();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin cá nhân')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Email: ${widget.email}'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fullNameCtrl,
                  decoration: const InputDecoration(labelText: 'Họ tên'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập họ tên'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _birthYearCtrl,
                  decoration: const InputDecoration(labelText: 'Năm sinh'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập năm sinh';
                    }
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 1900 || n > DateTime.now().year) {
                      return 'Năm sinh không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Vai trò'),
                  items: const [
                    DropdownMenuItem(value: 'staff', child: Text('Nhân viên')),
                    DropdownMenuItem(
                      value: 'owner',
                      child: Text('Chủ cửa hàng'),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _role = v ?? 'staff');
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập số điện thoại';
                    }
                    final cleaned = v.replaceAll(RegExp(r'[^0-9]'), '');
                    if (cleaned.length < 7) return 'Số điện thoại không hợp lệ';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(labelText: 'Địa chỉ'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập địa chỉ';
                    }
                    return null;
                  },
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
                  onChanged: (v) {
                    setState(() => _gender = v ?? 'male');
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _startDateCtrl,
                  readOnly: true,
                  onTap: _pickStartDate,
                  decoration: const InputDecoration(labelText: 'Ngày bắt đầu'),
                  validator: (_) {
                    if (_startDate == null) {
                      return 'Vui lòng chọn ngày bắt đầu';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveProfile,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('Hoàn tất', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
