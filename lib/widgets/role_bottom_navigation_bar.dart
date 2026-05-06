import 'package:flutter/material.dart';

enum RoleBottomTab {
  home,
  employees,
  scan,
  invoices,
  offers,
  cart,
  orders,
  account,
}

class RoleBottomNavigationBar extends StatelessWidget {
  final String role;
  final RoleBottomTab currentTab;
  final ValueChanged<RoleBottomTab> onTabSelected;

  const RoleBottomNavigationBar({
    super.key,
    required this.role,
    required this.currentTab,
    required this.onTabSelected,
  });

  static const Color _activeColor = Color(0xFF2563EB);
  static const Color _inactiveColor = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    if (role == 'admin') return _adminBar();
    if (role == 'employee') return _employeeBar();
    if (role == 'customer') return _customerBar();
    return const SizedBox.shrink();
  }

  Widget _adminBar() {
    final tabs = [
      _TabData(RoleBottomTab.home, Icons.home_outlined, Icons.home, 'Home'),
      _TabData(
        RoleBottomTab.employees,
        Icons.people_alt_outlined,
        Icons.people_alt,
        'Nhân viên',
      ),
      _TabData(
        RoleBottomTab.invoices,
        Icons.receipt_long_outlined,
        Icons.receipt_long,
        'Hóa đơn',
      ),
      _TabData(
        RoleBottomTab.cart,
        Icons.shopping_cart_outlined,
        Icons.shopping_cart,
        'Giỏ hàng',
      ),
      _TabData(
        RoleBottomTab.account,
        Icons.person_outline,
        Icons.person,
        'Tài khoản',
      ),
    ];

    return _BarShell(child: _bottomBar(tabs));
  }

  Widget _employeeBar() {
    final tabs = [
      _TabData(RoleBottomTab.home, Icons.home_outlined, Icons.home, 'Home'),
      _TabData(
        RoleBottomTab.scan,
        Icons.qr_code_scanner,
        Icons.qr_code_scanner,
        'Quét mã',
      ),
      _TabData(
        RoleBottomTab.cart,
        Icons.shopping_cart_outlined,
        Icons.shopping_cart,
        'Giỏ hàng',
      ),
      _TabData(
        RoleBottomTab.invoices,
        Icons.receipt_long_outlined,
        Icons.receipt_long,
        'Hóa đơn',
      ),
      _TabData(
        RoleBottomTab.account,
        Icons.person_outline,
        Icons.person,
        'Tài khoản',
      ),
    ];

    return _BarShell(child: _bottomBar(tabs));
  }

  Widget _customerBar() {
    final tabs = [
      _TabData(RoleBottomTab.home, Icons.home_outlined, Icons.home, 'Home'),
      _TabData(
        RoleBottomTab.offers,
        Icons.local_offer_outlined,
        Icons.local_offer,
        'Ưu đãi',
      ),
      _TabData(
        RoleBottomTab.cart,
        Icons.shopping_cart_outlined,
        Icons.shopping_cart,
        'Giỏ hàng',
      ),
      _TabData(
        RoleBottomTab.orders,
        Icons.receipt_long_outlined,
        Icons.receipt_long,
        'Đơn hàng',
      ),
      _TabData(
        RoleBottomTab.account,
        Icons.person_outline,
        Icons.person,
        'Tài khoản',
      ),
    ];

    return _BarShell(child: _bottomBar(tabs));
  }

  BottomNavigationBar _bottomBar(List<_TabData> tabs) {
    final index = tabs.indexWhere((tab) => tab.tab == currentTab);
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: index < 0 ? 0 : index,
      selectedItemColor: _activeColor,
      unselectedItemColor: _inactiveColor,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      showUnselectedLabels: true,
      elevation: 0,
      backgroundColor: Colors.white,
      onTap: (index) => onTabSelected(tabs[index].tab),
      items: tabs
          .map(
            (tab) => BottomNavigationBarItem(
              icon: Icon(tab.icon),
              activeIcon: Icon(tab.activeIcon),
              label: tab.label,
            ),
          )
          .toList(),
    );
  }
}

class _BarShell extends StatelessWidget {
  final Widget child;

  const _BarShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _TabData {
  final RoleBottomTab tab;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _TabData(this.tab, this.icon, this.activeIcon, this.label);
}
