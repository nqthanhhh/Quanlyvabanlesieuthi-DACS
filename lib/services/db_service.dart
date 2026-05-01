import 'package:hive_flutter/hive_flutter.dart';
import '../models/product.dart';
import '../models/inventory_item.dart';
import '../models/user.dart';
import '../models/order.dart';
import '../models/order_line.dart';
import '../models/inventory_history_entry.dart';
import 'api_service.dart';

class DBService {
  static const int cacheSchemaVersion = 2;
  static const String productsBox = 'products';
  static const String usersBox = 'users';
  static const String ordersBox = 'orders';
  static const String settingsBox = 'settings';
  static const String cartsBox = 'carts';
  static const String productImagesBox = 'product_images';
  static const String inventoryProductsBox = 'inventory_products';
  static const String inventoryHistoryBox =
      'inventory_history_box'; // <<< THÊM HẰNG SỐ BOX

  static Future<void> init() async {
    // 1. Initialize Hive & Register Adapters
    await Hive.initFlutter();
    _registerAdapterOnce(ProductAdapter());
    _registerAdapterOnce(InventoryItemAdapter());
    _registerAdapterOnce(UserAdapter());
    _registerAdapterOnce(OrderAdapter());
    _registerAdapterOnce(OrderLineAdapter());
    _registerAdapterOnce(InventoryHistoryEntryAdapter());

    await Hive.openBox(settingsBox);
    await _deleteOldCacheFromDiskIfNeeded();

    // 2. Open Boxes
    await Hive.openBox<Product>(productsBox);
    await Hive.openBox<User>(usersBox);
    await Hive.openBox<Order>(ordersBox);
    await Hive.openBox<InventoryItem>(inventoryProductsBox);
    await Hive.openBox<InventoryHistoryEntry>(inventoryHistoryBox);
    await Hive.openBox<String>(productImagesBox);
    await Hive.openBox(cartsBox);

    // 3. Migrate product keys (if they were stored with numeric keys)
    try {
      await _migrateProductsToIdKeys();
    } catch (e) {
      print('Cache sản phẩm cũ không tương thích, xóa cache: $e');
      await _clearRuntimeCache();
    }

    // 4. Pull remote data into the local cache. If the API is not running,
    // keep the app usable with the existing Hive cache/sample data.
    try {
      await syncAllFromApi();
    } catch (e) {
      print('Không đồng bộ được API, dùng cache Hive: $e');
      await seedProducts();
      await seedInventory();
      await seedUsers();
    }
  }

  // CÁC HÀM GETTER
  static Box<Product> products() => Hive.box<Product>(productsBox);
  static Box<InventoryItem> inventoryProducts() =>
      Hive.box<InventoryItem>(inventoryProductsBox);
  static Box<InventoryHistoryEntry> inventoryHistory() =>
      Hive.box<InventoryHistoryEntry>(inventoryHistoryBox);
  static Box<User> users() => Hive.box<User>(usersBox);
  static Box<Order> orders() => Hive.box<Order>(ordersBox);
  static Box carts() => Hive.box(cartsBox);
  static Box settings() => Hive.box(settingsBox);
  static Box<String> productImages() => Hive.box<String>(productImagesBox);

  static void _registerAdapterOnce<T>(TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
    }
  }

  static Future<void> _deleteOldCacheFromDiskIfNeeded() async {
    final box = settings();
    final currentVersion = box.get('cache_schema_version');
    if (currentVersion == cacheSchemaVersion) return;

    for (final boxName in [
      productsBox,
      usersBox,
      ordersBox,
      cartsBox,
      productImagesBox,
      inventoryProductsBox,
      inventoryHistoryBox,
    ]) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }
      await Hive.deleteBoxFromDisk(boxName);
    }

    await box.put('cache_schema_version', cacheSchemaVersion);
  }

  static Future<void> _clearRuntimeCache() async {
    await Future.wait([
      products().clear(),
      inventoryProducts().clear(),
      users().clear(),
      orders().clear(),
      inventoryHistory().clear(),
      productImages().clear(),
      carts().clear(),
    ]);
  }

  static Future<void> syncAllFromApi() async {
    await Future.wait([
      syncProductsFromApi(),
      syncInventoryItemsFromApi(),
      syncUsersFromApi(),
      syncOrdersFromApi(),
      syncInventoryHistoryFromApi(),
    ]);
  }

  static Future<void> syncProductsFromApi() async {
    final remoteProducts = await ApiService.fetchProducts();
    final productBox = products();
    final imageBox = productImages();
    await productBox.clear();

    for (final product in remoteProducts) {
      await productBox.put(product.id, product);
      if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
        await imageBox.put(product.id, product.imageUrl!);
      }
    }
  }

  static Future<void> syncInventoryItemsFromApi() async {
    final remoteItems = await ApiService.fetchInventoryItems();
    final box = inventoryProducts();
    await box.clear();
    for (final item in remoteItems) {
      await box.put(item.id, item);
    }
  }

  static Future<void> syncUsersFromApi() async {
    final remoteUsers = await ApiService.fetchUsers();
    final box = users();
    await box.clear();
    for (final user in remoteUsers) {
      await box.put(user.email, user);
    }
  }

  static Future<void> syncOrdersFromApi() async {
    final remoteOrders = await ApiService.fetchOrders();
    final box = orders();
    await box.clear();
    for (final order in remoteOrders) {
      await box.put(order.id, order);
    }
  }

  static Future<void> syncInventoryHistoryFromApi() async {
    final logs = await ApiService.fetchInventoryLogs();
    final box = inventoryHistory();
    await box.clear();
    for (final log in logs) {
      await box.add(
        InventoryHistoryEntry(
          id: (log['log_id'] ?? '${DateTime.now().microsecondsSinceEpoch}')
              .toString(),
          type: (log['action'] ?? '').toString().toLowerCase(),
          itemId: (log['inventory_item_id'] ?? log['product_id']).toString(),
          itemName: (log['item_name'] ?? log['product_name'] ?? '').toString(),
          unit: (log['unit'] ?? 'sp').toString(),
          quantityChange: _toInt(log['quantity']),
          beforeQuantity: 0,
          afterQuantity: 0,
          note: (log['note'] ?? '').toString(),
          createdAt:
              DateTime.tryParse((log['created_at'] ?? '').toString()) ??
              DateTime.now(),
        ),
      );
    }
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Future<void> addInventoryHistoryEntry(
    InventoryHistoryEntry entry,
  ) async {
    await inventoryHistory().put(entry.id, entry);
  }

  // --- LOGIC SEEDING ---

  static Future<void> seedProducts() async {
    final box = products();
    if (box.isEmpty) {
      final List<Product> sampleProducts = [
        Product(
          id: 'banana',
          name: 'Chuối tây',
          price: 3000.0,
          unit: 'nải',
          stockQuantity: 15,
        ),
        Product(
          id: 'apple',
          name: 'Táo đỏ',
          price: 20000.0,
          unit: 'kg',
          stockQuantity: 50,
        ),
        Product(
          id: 'coke',
          name: 'Nước Coke',
          price: 10000.0,
          unit: 'lon',
          stockQuantity: 100,
        ),
        Product(
          id: 'diet_coke',
          name: 'Diet Coke',
          price: 12000.0,
          unit: 'lon',
          stockQuantity: 80,
        ),
        Product(
          id: 'tomato',
          name: 'Cà chua',
          price: 15000.0,
          unit: 'kg',
          stockQuantity: 60,
        ),
        Product(
          id: 'brocoli',
          name: 'Bông cải',
          price: 25000.0,
          unit: 'cây',
          stockQuantity: 30,
        ),
      ];

      for (final p in sampleProducts) {
        await box.put(p.id, p);
      }

      print('--- ĐÃ TẠO ${sampleProducts.length} SẢN PHẨM MẪU ---');
    }
  }

  static Future<void> seedUsers() async {
    final box = users();
    if (box.isEmpty) {
      box.add(User(email: 'abc', password: '123', role: 'owner'));
      box.add(User(email: 'xyz', password: '123', role: 'staff'));
    }
  }

  static Future<void> seedInventory() async {
    final box = inventoryProducts();
    if (box.isEmpty) {
      final List<InventoryItem> sample = [
        InventoryItem(
          id: 'banana',
          name: 'Chuối tây',
          price: 30000.0,
          unit: 'nải',
          stockQuantity: 100,
        ),
        InventoryItem(
          id: 'apple',
          name: 'Táo đỏ',
          price: 20000.0,
          unit: 'kg',
          stockQuantity: 100,
        ),
        InventoryItem(
          id: 'coke',
          name: 'Nước Coke',
          price: 10000.0,
          unit: 'lon',
          stockQuantity: 100,
        ),
        InventoryItem(
          id: 'diet_coke',
          name: 'Diet Coke',
          price: 12000.0,
          unit: 'lon',
          stockQuantity: 100,
        ),
        InventoryItem(
          id: 'tomato',
          name: 'Cà chua',
          price: 15000.0,
          unit: 'kg',
          stockQuantity: 100,
        ),
        InventoryItem(
          id: 'brocoli',
          name: 'Bông cải',
          price: 25000.0,
          unit: 'cây',
          stockQuantity: 100,
        ),
      ];

      for (final it in sample) {
        await box.put(it.id, it);
      }

      print('--- ĐÃ TẠO ${sample.length} MẶT HÀNG KHO MẪU ---');
    }
  }

  // ✅ FIXED: tránh trùng instance HiveObject khi đổi key
  static Future<void> _migrateProductsToIdKeys() async {
    final box = products();
    final current = Map<dynamic, Product>.from(
      box.toMap().cast<dynamic, Product>(),
    );

    for (final e in current.entries) {
      final key = e.key;
      final oldProduct = e.value;

      // Chỉ xử lý nếu key không phải String
      if (key is! String) {
        // Tạo bản sao mới để tránh lỗi instance trùng key
        final newProduct = Product(
          id: oldProduct.id,
          name: oldProduct.name,
          price: oldProduct.price,
          unit: oldProduct.unit,
          stockQuantity: oldProduct.stockQuantity,
        );

        await box.put(newProduct.id, newProduct);
        await box.delete(key);
      }
    }
  }

  // --- LOGIC QUẢN LÝ KHO & BÁN HÀNG ---

  static Future<void> saveOrder(Order order) async {
    final employeeId = settings().get('current_user_id') as int?;
    final saved = await ApiService.createOrder(order, employeeId: employeeId);
    await orders().put(saved.id, saved);
    await syncProductsFromApi();
  }

  static List<Product> getAllProducts() {
    return products().values.toList();
  }

  static List<Order> getAllOrders() {
    final allOrders = orders().values.cast<Order>().toList();
    allOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
    return allOrders;
  }

  static int getOrderCount() {
    return orders().length;
  }

  static double getTotalRevenue() {
    return orders().values.fold(0.0, (sum, order) => sum + order.totalAmount);
  }

  static Map<String, int> getCartForUser(String email) {
    final raw = carts().get(email);
    if (raw == null) return <String, int>{};
    try {
      return Map<String, int>.from(raw as Map);
    } catch (_) {
      return <String, int>{};
    }
  }

  static Future<void> saveCartForUser(
    String email,
    Map<String, int> cart,
  ) async {
    final Map<String, int> cleanCart = Map.from(cart)
      ..removeWhere((key, value) => value <= 0);
    await carts().put(email, cleanCart);
    final userId = settings().get('current_user_id') as int?;
    if (userId != null) {
      await ApiService.saveCart(userId, cleanCart);
    }
  }

  static Future<Map<String, int>> loadCartForCurrentUser(String email) async {
    final userId = settings().get('current_user_id') as int?;
    if (userId == null) return getCartForUser(email);
    try {
      final remoteCart = await ApiService.fetchCart(userId);
      await carts().put(email, remoteCart);
      return remoteCart;
    } catch (_) {
      return getCartForUser(email);
    }
  }

  static Future<Product> createProduct(
    Product product, {
    String? imagePath,
  }) async {
    if (imagePath != null &&
        imagePath.isNotEmpty &&
        !imagePath.startsWith('http')) {
      product.imageUrl = await ApiService.uploadProductImage(imagePath);
    }
    final saved = await ApiService.createProduct(product);
    await products().put(saved.id, saved);
    if (saved.imageUrl != null) {
      await productImages().put(saved.id, saved.imageUrl!);
    }
    return saved;
  }

  static Future<Product> updateProductRemote(
    Product product, {
    String? imagePath,
  }) async {
    if (imagePath != null &&
        imagePath.isNotEmpty &&
        !imagePath.startsWith('http')) {
      product.imageUrl = await ApiService.uploadProductImage(imagePath);
    }
    final saved = await ApiService.updateProduct(product);
    await products().put(saved.id, saved);
    if (saved.imageUrl != null) {
      await productImages().put(saved.id, saved.imageUrl!);
    }
    return saved;
  }

  static Future<void> deleteProductRemote(Product product) async {
    await ApiService.deleteProduct(product.id);
    await products().delete(product.id);
    await productImages().delete(product.id);
  }

  static Future<void> importInventoryRemote({
    required InventoryItem item,
    required int quantity,
    String? note,
  }) async {
    final employeeId = settings().get('current_user_id') as int?;
    if (employeeId == null) {
      throw ApiException('Chưa có current_user_id để ghi lịch sử nhập kho');
    }
    await ApiService.importInventory(
      inventoryItemId: item.id,
      employeeId: employeeId,
      quantity: quantity,
      note: note,
    );
    await syncInventoryItemsFromApi();
    await syncInventoryHistoryFromApi();
  }

  static Future<void> adjustInventoryRemote({
    required InventoryItem item,
    required int actualQuantity,
    String? note,
  }) async {
    final employeeId = settings().get('current_user_id') as int?;
    if (employeeId == null) {
      throw ApiException('Chưa có current_user_id để ghi lịch sử kiểm kê');
    }
    await ApiService.adjustInventory(
      inventoryItemId: item.id,
      employeeId: employeeId,
      actualQuantity: actualQuantity,
      note: note,
    );
    await syncInventoryItemsFromApi();
    await syncInventoryHistoryFromApi();
  }

  static Future<InventoryItem> createInventoryItemRemote({
    required String barcode,
    required String name,
    required double price,
    required String unit,
    required int quantity,
    String? imagePath,
  }) async {
    final item = InventoryItem(
      name: name,
      price: price,
      unit: unit,
      id: barcode,
      stockQuantity: 0,
    );

    final saved = await ApiService.createInventoryItem(item);
    await inventoryProducts().put(saved.id, saved);
    if (imagePath != null && imagePath.isNotEmpty) {
      await productImages().put(saved.id, imagePath);
    }
    await importInventoryRemote(
      item: saved,
      quantity: quantity,
      note: 'Tạo mặt hàng kho',
    );
    return inventoryProducts().get(saved.id) ?? saved;
  }

  static Future<Product> releaseInventoryToShelf({
    required InventoryItem item,
    required int quantity,
    required int categoryId,
  }) async {
    Product? existing;
    for (final product in products().values) {
      if (product.barcode == item.id || product.id == item.id) {
        existing = product;
        break;
      }
    }

    Product saved;
    if (existing != null) {
      existing.stockQuantity += quantity;
      saved = await updateProductRemote(existing);
    } else {
      saved = await createProduct(
        Product(
          id: '0',
          name: item.name,
          price: item.price,
          unit: item.unit,
          barcode: item.id,
          stockQuantity: quantity,
          categoryId: categoryId,
        ),
      );
    }

    final employeeId = settings().get('current_user_id') as int?;
    if (employeeId == null) {
      throw ApiException('Chưa có current_user_id để ghi lịch sử xuất kho');
    }
    await ApiService.exportInventory(
      inventoryItemId: item.id,
      productId: saved.id,
      employeeId: employeeId,
      quantity: quantity,
      note: 'Đưa hàng lên kệ',
    );
    await syncProductsFromApi();
    await syncInventoryItemsFromApi();
    await syncInventoryHistoryFromApi();
    return products().get(saved.id) ?? saved;
  }

  static List<Product> searchProducts(String query, List<Product> source) {
    if (query.isEmpty) {
      return source;
    }
    final lowerQuery = query.toLowerCase();
    return source
        .where(
          (p) =>
              p.name.toLowerCase().contains(lowerQuery) ||
              p.id.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

}
