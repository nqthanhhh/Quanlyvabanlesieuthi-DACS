import 'dart:io';

import 'package:flutter/material.dart';
import '../widgets/role_bottom_navigation_bar.dart';
import '../widgets/slide_page_route.dart';
import '../services/db_service.dart';
import '../models/user.dart';
import 'checkout_screen.dart';
import 'employee.dart';
import 'order_management_screen.dart';
import 'profile_edit_screen.dart';
import 'scan_product_screen.dart';

class ProfileViewScreen extends StatefulWidget {
  final String role;

  const ProfileViewScreen({super.key, required this.role});

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

  Future<void> _openCheckoutFromTab() async {
    final email = DBService.settings().get('current_user_email') as String?;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy người dùng hiện tại')),
      );
      return;
    }

    final cart = await DBService.loadCartForCurrentUser(email);
    if (cart.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Giỏ hàng đang trống')));
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      buildSlidePageRoute(
        CheckoutScreen(
          cart: Map<String, int>.from(cart),
          role: widget.role,
          onCheckoutComplete: () async {
            await DBService.saveCartForUser(email, <String, int>{});
          },
        ),
      ),
    );
  }

  Future<void> _scanAndOpenCart() async {
    final product = await Navigator.of(
      context,
    ).push(buildSlidePageRoute(const ScanProductScreen()));
    if (product == null || !mounted) return;
    try {
      final cart = await DBService.addProductToCurrentCart(product);
      if (!mounted) return;
      Navigator.of(context).push(
        buildSlidePageRoute(
          CheckoutScreen(
            cart: cart,
            role: widget.role,
            onCheckoutComplete: () async {
              final email = DBService.currentUserEmail();
              if (email != null) {
                await DBService.saveCartForUser(email, <String, int>{});
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _handleBottomTab(RoleBottomTab tab) {
    switch (tab) {
      case RoleBottomTab.home:
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
      case RoleBottomTab.invoices:
        Navigator.of(context).pushReplacement(
          buildSlidePageRoute(OrderManagementScreen(role: widget.role)),
        );
        break;
      case RoleBottomTab.employees:
        Navigator.of(context).pushReplacement(
          buildSlidePageRoute(EmployeeManagementScreen(role: widget.role)),
        );
        break;
      case RoleBottomTab.account:
        break;
      case RoleBottomTab.cart:
        _openCheckoutFromTab();
        break;
      case RoleBottomTab.scan:
        _scanAndOpenCart();
        break;
      case RoleBottomTab.offers:
      case RoleBottomTab.orders:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thông tin cá nhân')),
        body: const Center(child: Text('Không tìm thấy thông tin người dùng')),
        bottomNavigationBar: RoleBottomNavigationBar(
          role: widget.role,
          currentTab: RoleBottomTab.account,
          onTabSelected: _handleBottomTab,
        ),
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
                      user.role == 'admin'
                          ? 'Quản lý'
                          : user.role == 'employee'
                          ? 'Nhân viên'
                          : 'Khách hàng',
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
      bottomNavigationBar: RoleBottomNavigationBar(
        role: widget.role,
        currentTab: RoleBottomTab.account,
        onTabSelected: _handleBottomTab,
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
