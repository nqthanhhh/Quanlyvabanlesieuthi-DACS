import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/db_service.dart';
import '../models/product.dart';
import 'profile_view_screen.dart';
import 'checkout_screen.dart';
import 'RevenueOverviewScreen.dart'; // Đã thêm
import 'product_management_screen.dart';
import 'inventory_management_screen.dart';
import 'employee.dart';
import 'customer_management_screen.dart';
import 'order_list_screen.dart';
import 'order_management_screen.dart';
import 'product_performance_report_screen.dart';
import 'security_info_screen.dart';
import '../widgets/role_bottom_navigation_bar.dart';

// --- WIDGET CHÍNH ---
class HomeScreen extends StatefulWidget {
  final String role;
  final VoidCallback onLogout;

  const HomeScreen({super.key, required this.role, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Map<String, int> _cart = {};
  String? _currentUserEmail;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  RoleBottomTab _currentBottomTab = RoleBottomTab.home;
  bool _isLoading = true;
  // *** INFINITE SCROLL LOGIC ***
  final ScrollController _scrollController = ScrollController();
  final int _productsPerPage = 6;
  int _loadedProductCount = 6;
  bool _isLoadingMore = false;
  // *****************************
  List<Product> _allProducts = [];
  List<Product> _displayedProducts = [];

  // Mapping ID sản phẩm sang đường dẫn hình ảnh
  String _imageFor(String id) {
    switch (id) {
      case 'banana':
        return 'assets/images/chuoi.png'; // Đã cập nhật theo file bạn gửi
      case 'apple':
        return 'assets/images/tao.png'; // Giả định anh1.png là táo
      case 'coke':
        return 'assets/images/nuoccoca.png';
      case 'diet_coke':
        return 'assets/images/dietcoca.png';
      case 'tomato':
        return 'assets/images/cachua.png';
      case 'brocoli':
        return 'assets/images/bongcai.png';

      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUserCart();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // Hàm tải giỏ hàng người dùng
  Future<void> _loadCurrentUserCart() async {
    final settings = DBService.settings();
    final email = settings.get('current_user_email') as String?;
    _currentUserEmail = email;
    if (email != null) {
      final saved = await DBService.loadCartForCurrentUser(email);
      if (saved.isNotEmpty) {
        setState(() {
          _cart
            ..clear()
            ..addAll(saved);
        });
      }
    }
  }

  Future<void> _persistCart() async {
    if (_currentUserEmail != null) {
      await DBService.saveCartForUser(_currentUserEmail!, _cart);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreProducts();
    }
  }

  void _loadMoreProducts() {
    if (_isLoadingMore) return;

    final allItems = DBService.products().values.toList().cast<Product>();

    if (_loadedProductCount >= allItems.length) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Giả lập độ trễ tải
    Future.delayed(const Duration(milliseconds: 1000), () {
      setState(() {
        _loadedProductCount += _productsPerPage;
        _isLoadingMore = false;
      });
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  // --- HÀM TÁCH WIDGET ---

  // Tách Widget Drawer
  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileSection(), // Tách Profile Section
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: _buildDrawerMenuItems(), // Tách Menu Items
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tách Menu Items
  List<Widget> _buildDrawerMenuItems() {
    final List<Widget> items = [
      ListTile(
        leading: const Icon(Icons.lock_outline),
        title: const Text('Thông tin bảo mật'),
        onTap: () {
          Navigator.of(context).pop(); // Đóng Drawer

          // Điều hướng đến màn hình đổi mật khẩu
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const SecurityInfoScreen(), // SỬ DỤNG CLASS ĐÃ IMPORT
            ),
          );
        },
      ),
    ];

    if (widget.role == 'admin') {
      items.insertAll(0, [
        ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: const Text('Xem doanh thu và lợi nhuận'),
          onTap: () {
            Navigator.of(context).pop(); // Đóng Drawer
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RevenueOverviewScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.bar_chart_outlined),
          title: const Text('Xem báo cáo hiệu suất sản phẩm'),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProductPerformanceReportScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.groups_outlined),
          title: const Text('Quản lý khách hàng'),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CustomerManagementScreen(),
              ),
            );
          },
        ),
      ]);
    } else if (widget.role == 'employee') {
      items.insertAll(0, [
        ListTile(
          leading: const Icon(Icons.inventory_2_outlined),
          title: const Text('Quản lý sản phẩm'),
          onTap: () {
            Navigator.of(context).pop(); // Đóng Drawer
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProductManagementScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.inventory),
          title: const Text('Quản lý kho hàng'),
          onTap: () {
            Navigator.of(context).pop(); // Đóng Drawer
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const InventoryManagementScreen(),
              ),
            );
          },
        ),
      ]);
    }
    return items;
  }

  // Tách Profile Section trong Drawer
  Widget _buildProfileSection() {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ProfileViewScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12, width: 6),
                ),
                child: const Center(
                  child: Icon(Icons.person_outline, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Thông tin cá nhân',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Divider(),
          ],
        ),
      ),
    );
  }

  // Tách App Bar Title (Search Bar)
  // Tách App Bar Title (Search Bar)
  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController, // Gắn controller
        decoration: InputDecoration(
          hintText: 'Search Store',
          prefixIcon: const Icon(Icons.search, color: Colors.black45),
          // Nút xoá (chỉ hiện khi có chữ)
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.black45),
                  onPressed: () {
                    _searchController
                        .clear(); // Xoá chữ và gọi _onSearchChanged
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 8,
          ),
        ),
      ),
    );
  }

  // Tách Widget Card Sản phẩm (Đã tối ưu UI theo mẫu)
  Widget _buildProductCard(Product p) {
    print('🧩 DEBUG: ${p.name} có id là "${p.id}"');

    final img = _imageFor(p.id);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Thêm vào giỏ khi chạm vào toàn bộ thẻ sản phẩm
          if (p.stockQuantity <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Sản phẩm "${p.name}" đã hết hàng')),
            );
            return;
          }
          _addToCart(p);
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Builder(
                    builder: (context) {
                      // Nếu có ảnh người dùng thêm, hiển thị ảnh từ file
                      final userImagePath = DBService.productImages().get(p.id);
                      if (userImagePath != null && userImagePath.isNotEmpty) {
                        final file = File(userImagePath);
                        if (file.existsSync()) {
                          return Image.file(
                            file,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.grey.shade100,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image,
                                size: 36,
                                color: Colors.black26,
                              ),
                            ),
                          );
                        }
                      }

                      // Nếu không có ảnh người dùng, dùng ảnh mặc định theo id
                      return img.isNotEmpty
                          ? Image.asset(
                              img,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (c, e, s) => Container(
                                color: Colors.grey.shade100,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image,
                                  size: 36,
                                  color: Colors.black26,
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.image,
                                  size: 36,
                                  color: Colors.black26,
                                ),
                              ),
                            );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                p.name, // Ví dụ: Chuối tây
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              // Dòng Khối lượng/Giá (Dòng nhỏ)
              Text(
                // Format theo mẫu: '500g, giá'
                '${p.stockQuantity}, Giá',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Giá tiền (Font lớn, đậm)
                  Text(
                    // Hiển thị giá và thêm ký hiệu '$'
                    '${p.price.toString()}\$',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  // Nút Thêm (+) - disabled nếu hết hàng
                  GestureDetector(
                    onTap: () async {
                      // Nếu hết hàng, thông báo và không thêm
                      if (p.stockQuantity <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sản phẩm "${p.name}" đã hết hàng'),
                          ),
                        );
                        return;
                      }
                      _addToCart(p);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: p.stockQuantity <= 0
                            ? Colors.grey.shade400
                            : Colors.orange.shade400,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tách Logic Thêm vào giỏ hàng
  void _addToCart(Product p) {
    // Kiểm tra tồn kho dựa vào số lượng hiện có trong giỏ
    final current = _cart[p.id] ?? 0;
    if (current + 1 > p.stockQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã hết hàng, không thể thêm ${p.name}.')),
      );
      return;
    }

    setState(() {
      _cart.update(p.id, (v) => v + 1, ifAbsent: () => 1);
    });
    Future.microtask(() => _persistCart());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${p.name} vào giỏ hàng'),
        duration: const Duration(milliseconds: 100),
      ),
    );
  }

  void _handleBottomTab(RoleBottomTab tab) {
    setState(() => _currentBottomTab = tab);

    switch (tab) {
      case RoleBottomTab.home:
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
        break;
      case RoleBottomTab.employees:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => EmployeeManagementScreen()));
        break;
      case RoleBottomTab.scan:
        _showScanPlaceholder();
        break;
      case RoleBottomTab.invoices:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => OrderManagementScreen()));
        break;
      case RoleBottomTab.offers:
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang hiển thị ưu đãi hôm nay')),
        );
        break;
      case RoleBottomTab.cart:
        _openCartSheet(context);
        break;
      case RoleBottomTab.orders:
        final rawUserId = DBService.settings().get('current_user_id');
        final currentUserId = rawUserId is int
            ? rawUserId
            : int.tryParse(rawUserId?.toString() ?? '');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderListScreen(customerId: currentUserId),
          ),
        );
        break;
      case RoleBottomTab.account:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ProfileViewScreen()));
        break;
    }
  }

  void _showScanPlaceholder() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quét mã'),
        content: const Text('Chức năng quét mã sẽ được kết nối ở bước sau.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(), // Sử dụng Widget đã tách
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: _buildSearchBar(), // Sử dụng Widget đã tách
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout, color: Colors.black87),
          ),
        ],
      ),

      // LOẠI BỎ SingleChildScrollView
      body: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Promo banner (Image)
            const _PromoBanner(), // Tách thành Widget riêng
            const SizedBox(height: 16),

            // Tiêu đề Ưu đãi hôm nay
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ưu đãi hôm nay',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                TextButton(onPressed: () {}, child: const Text('Tất cả')),
              ],
            ),
            const SizedBox(height: 8),

            // Danh sách sản phẩm (Đã thêm Expanded cho Infinite Scrolling)
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: DBService.products().listenable(),
                builder: (context, Box<Product> box, _) {
                  final allItems = box.values.toList().cast<Product>();
                  final List<Product> filteredItems;

                  // 1. Lọc sản phẩm theo truy vấn tìm kiếm (prefix match)
                  if (_searchQuery.isEmpty) {
                    filteredItems = allItems; // Không tìm, dùng tất cả
                  } else {
                    final q = _searchQuery;
                    filteredItems = allItems.where((product) {
                      final name = product.name.toLowerCase();
                      // Nếu truy vấn dài hơn tên sản phẩm, không khớp
                      if (q.length > name.length) return false;
                      // So khớp tiền tố: gõ 1 ký tự -> lọc theo ký tự đầu, 2 ký tự -> 2 ký tự đầu, v.v.
                      return name.startsWith(q);
                    }).toList();
                  }

                  // 2. ✅ SỬA LỖI Ở ĐÂY: Gán kết quả cho biến
                  final itemsToShow = filteredItems
                      .take(_loadedProductCount)
                      .toList();
                  final hasMore = filteredItems.length > itemsToShow.length;

                  // 3. Kiểm tra danh sách rỗng
                  if (itemsToShow.isEmpty) {
                    if (_searchQuery.isNotEmpty) {
                      return const Center(
                        child: Text('Không tìm thấy sản phẩm nào.'),
                      );
                    }
                    return const _NoProductsFound();
                  }

                  // 4. Trả về GridView
                  return GridView.builder(
                    controller: _scrollController,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 3 / 4,
                        ),
                    itemCount: itemsToShow.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == itemsToShow.length && hasMore) {
                        return const _LoadingFooter();
                      }

                      final Product p = itemsToShow[index];
                      return _buildProductCard(p);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: null,
      bottomNavigationBar: RoleBottomNavigationBar(
        role: widget.role,
        currentTab: _currentBottomTab,
        onTabSelected: _handleBottomTab,
      ),
    );
  }

  // Tách Floating Action Button
  Widget _buildCartFloatingActionButton() {
    final totalItems = _cart.values.fold<int>(0, (a, b) => a + b);

    return FloatingActionButton(
      onPressed: () => _openCartSheet(context),
      backgroundColor: Colors.orange.shade400,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.shopping_cart),
          if (_cart.isNotEmpty)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  totalItems.toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Tách Cart Sheet
  void _openCartSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, modalSetState) {
            final productsBox = DBService.products();
            final items = productsBox.values
                .where((p) => _cart.containsKey(p.id))
                .toList();
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.5,
              minChildSize: 0.25,
              maxChildSize: 0.9,
              builder: (_, controller) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const _ModalDragHandle(), // Tách Widget
                    const SizedBox(height: 12),
                    const Text(
                      'Giỏ hàng',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(child: Text('Giỏ hàng trống'))
                          : ListView.builder(
                              controller: controller,
                              itemCount: items.length,
                              itemBuilder: (context, i) {
                                final p = items[i];
                                final qty = _cart[p.id] ?? 0;
                                return _buildCartItemTile(
                                  p,
                                  qty,
                                  modalSetState,
                                ); // Tách Cart Item
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    _buildCheckoutButton(items.isEmpty), // Tách Checkout Button
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Tách Cart Item Tile
  Widget _buildCartItemTile(Product p, int qty, StateSetter modalSetState) {
    return ListTile(
      leading: SizedBox(
        width: 48,
        height: 48,
        child: _imageFor(p.id).isNotEmpty
            ? Image.asset(_imageFor(p.id), fit: BoxFit.cover)
            : const Icon(Icons.image_outlined),
      ),
      title: Text(p.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decrement
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () {
              modalSetState(() {
                final cur = _cart[p.id] ?? 0;
                if (cur <= 1) {
                  _cart.remove(p.id);
                } else {
                  _cart[p.id] = cur - 1;
                }
              });
              setState(() {});
              Future.microtask(() => _persistCart());
            },
          ),
          Text(qty.toString()),
          // Increment - chỉ khi còn trong kho
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              // Nếu đã đạt giới hạn tồn kho, không cho tăng
              if ((qty + 1) > p.stockQuantity) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Không thể tăng số lượng. Chỉ còn ${p.stockQuantity} của ${p.name} trong kho.',
                    ),
                  ),
                );
                return;
              }
              modalSetState(() {
                _cart.update(p.id, (v) => v + 1, ifAbsent: () => 1);
              });
              setState(() {});
              Future.microtask(() => _persistCart());
            },
          ),
          // Delete
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              final confirm = await _showDeleteConfirmation(context, p.name);
              if (confirm == true) {
                modalSetState(() {
                  _cart.remove(p.id);
                });
                setState(() {});
                Future.microtask(() => _persistCart());
              }
            },
          ),
        ],
      ),
    );
  }

  // Tách Checkout Button
  Widget _buildCheckoutButton(bool cartIsEmpty) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: cartIsEmpty
                ? null
                : () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CheckoutScreen(
                          cart: Map.from(_cart),
                          onCheckoutComplete: () async {
                            setState(() => _cart.clear());
                            await _persistCart();
                          },
                        ),
                      ),
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade400,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text(
              'Thanh toán',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // Tách Dialog Xác nhận xoá
  Future<bool?> _showDeleteConfirmation(
    BuildContext context,
    String productName,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Xác nhận xoá'),
        content: Text(
          'Bạn có chắc muốn xoá "$productName" khỏi giỏ hàng không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET ĐỘC LẬP DÙNG CONST ---

// 1. Banner quảng cáo
class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/images/banner.png',
        width: double.infinity,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(
          height: 100,
          color: Colors.orange.shade50,
          alignment: Alignment.center,
          child: const Text('Banner'),
        ),
      ),
    );
  }
}

// 2. Loading Indicator ở cuối danh sách
class _LoadingFooter extends StatelessWidget {
  const _LoadingFooter();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

// 3. Thông báo không tìm thấy sản phẩm
class _NoProductsFound extends StatelessWidget {
  const _NoProductsFound();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24.0),
      child: Center(child: Text('Không có sản phẩm')),
    );
  }
}

// 4. Thanh kéo của Modal
class _ModalDragHandle extends StatelessWidget {
  const _ModalDragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
