import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/db_service.dart';

class AddEditEmployeeScreen extends StatefulWidget {
  final User? user; // if null -> create

  const AddEditEmployeeScreen({super.key, this.user});

  @override
  State<AddEditEmployeeScreen> createState() => _AddEditEmployeeScreenState();
}

class _AddEditEmployeeScreenState extends State<AddEditEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _email;
  late String _password;
  bool _obscurePassword = true;
  String _role = 'staff';
  String _fullName = '';
  String _phone = '';
  String _address = '';
  DateTime? _startDate;
  int _birthYear = 0;

  bool get isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final u = widget.user!;
      _email = u.email;
      _password = u.password;
      _role = u.role;
      _fullName = u.fullName;
      _phone = u.phone;
      _address = u.address;
      _birthYear = u.birthYear;
      _startDate = u.startDate;
    } else {
      _email = '';
      _password = '';
    }
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final initial = _startDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    // Check email uniqueness
    final users = DBService.users().values.cast<User>().toList();
    final emailExists = users.any((u) {
      if (isEditing) {
        // allow current user's email
        return u.email == _email && u.key != widget.user!.key;
      }
      return u.email == _email;
    });

    if (emailExists) {
      // show error and abort save
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Lỗi'),
          content: const Text('Email này đã được sử dụng bởi tài khoản khác.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
      return;
    }

    if (isEditing) {
      final u = widget.user!;
      u.email = _email;
      u.password = _password;
      u.role = _role;
      u.fullName = _fullName;
      u.phone = _phone;
      u.address = _address;
      u.birthYear = _birthYear;
      u.startDate = _startDate;
      await u.save();
    } else {
      final newUser = User(
        email: _email,
        password: _password,
        role: _role,
        fullName: _fullName,
        phone: _phone,
        address: _address,
        birthYear: _birthYear,
        startDate: _startDate,
      );
      await DBService.users().add(newUser);
    }

    Navigator.of(context).pop(true); // notify caller to refresh
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Sửa nhân viên' : 'Thêm nhân viên'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                initialValue: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Vui lòng nhập email' : null,
                onSaved: (v) => _email = v!.trim(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
                onSaved: (v) => _password = v!.trim(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _role,
                items: const [
                  DropdownMenuItem(value: 'owner', child: Text('Quản lý')),
                  DropdownMenuItem(value: 'staff', child: Text('Nhân viên')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'staff'),
                decoration: const InputDecoration(labelText: 'Vai trò'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _fullName,
                decoration: const InputDecoration(labelText: 'Tên đầy đủ'),
                onSaved: (v) => _fullName = v?.trim() ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                keyboardType: TextInputType.phone,
                onSaved: (v) => _phone = v?.trim() ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _address,
                decoration: const InputDecoration(labelText: 'Địa chỉ'),
                onSaved: (v) => _address = v?.trim() ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _birthYear == 0 ? '' : '$_birthYear',
                decoration: const InputDecoration(labelText: 'Năm sinh'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return null; // optional
                  final parsed = int.tryParse(v);
                  if (parsed == null) return 'Năm sinh không hợp lệ';
                  if (parsed < 1900 || parsed > DateTime.now().year)
                    return 'Năm sinh không hợp lệ';
                  return null;
                },
                onSaved: (v) =>
                    _birthYear = (v == null || v.isEmpty) ? 0 : int.parse(v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _startDate == null
                          ? 'Chưa có ngày bắt đầu'
                          : 'Bắt đầu: ${_startDate!.toLocal().toIso8601String().split('T').first}',
                    ),
                  ),
                  TextButton(
                    onPressed: _pickStartDate,
                    child: const Text('Chọn ngày'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _save, child: const Text('Lưu')),
            ],
          ),
        ),
      ),
    );
  }
}
