import 'package:hive_flutter/hive_flutter.dart';
import '../models/product.dart';
import '../models/inventory_item.dart';
import '../models/user.dart';
import '../models/order.dart';
import '../models/order_line.dart';

class DBService {
  static const String productsBox = 'products';
  static const String usersBox = 'users';
  static const String ordersBox = 'orders';
  static const String settingsBox = 'settings';
  static const String cartsBox = 'carts';
  static const String productImagesBox = 'product_images';
  static const String inventoryProductsBox = 'inventory_products';

  static Future<void> init() async {
    // 1. Initialize Hive & Register Adapters
    await Hive.initFlutter();
    Hive.registerAdapter(ProductAdapter());
    Hive.registerAdapter(InventoryItemAdapter());
    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(OrderAdapter());
    Hive.registerAdapter(OrderLineAdapter());

    // 2. Open Boxes
    await Hive.openBox<Product>(productsBox);
    await Hive.openBox<User>(usersBox);
    await Hive.openBox<Order>(ordersBox);
    await Hive.openBox<InventoryItem>(inventoryProductsBox);
    await Hive.openBox<String>(productImagesBox);
    await Hive.openBox(cartsBox);
    await Hive.openBox(settingsBox);

    // 3. Migrate product keys (if they were stored with numeric keys)
    await _migrateProductsToIdKeys();

    // 4. Seed Data
    await seedProducts();
    await seedInventory();
    await seedUsers();
  }

  // CÁC HÀM GETTER
  static Box<Product> products() => Hive.box<Product>(productsBox);
  static Box<InventoryItem> inventoryProducts() =>
      Hive.box<InventoryItem>(inventoryProductsBox);
  static Box<User> users() => Hive.box<User>(usersBox);
  static Box<Order> orders() => Hive.box<Order>(ordersBox);
  static Box carts() => Hive.box(cartsBox);
  static Box settings() => Hive.box(settingsBox);
  static Box<String> productImages() => Hive.box<String>(productImagesBox);

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
          stockQuantity: 10,
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
    await orders().put(order.id, order);

    for (var line in order.items) {
      final product = products().get(line.productId);
      if (product != null) {
        product.stockQuantity -= line.quantity;
        if (product.stockQuantity < 0) {
          product.stockQuantity = 0;
        }
        await product.save();
      }
    }
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

  // --- INVENTORY SYNC HELPERS ---
  // Ensure there is an InventoryItem for the given product. This will only
  // create the inventory record if it doesn't already exist. We copy
  // metadata (id, name, price, unit) and set the initial stock to the
  // product's stockQuantity at creation time.
  static Future<void> ensureInventoryForProduct(Product product) async {
    final box = inventoryProducts();
    if (!box.containsKey(product.id)) {
      final inv = InventoryItem(
        id: product.id,
        name: product.name,
        price: product.price,
        unit: product.unit,
        stockQuantity: product.stockQuantity,
      );
      await box.put(inv.id, inv);
    }
  }

  // Update inventory metadata (name/price/unit) for a product if the
  // inventory record exists. We intentionally do NOT change the
  // inventory stockQuantity here to keep product and inventory stocks
  // separate unless the user explicitly requests synchronization.
  static Future<void> updateInventoryMetadataForProduct(Product product) async {
    final box = inventoryProducts();
    if (box.containsKey(product.id)) {
      final existing = box.get(product.id) as InventoryItem;
      existing.name = product.name;
      existing.price = product.price;
      existing.unit = product.unit;
      await box.put(existing.id, existing);
    }
  }

  // Try to reduce inventory stock by [amount] for item with [id].
  // Returns:
  // - remaining stock (>= 0) on success,
  // - -1 if inventory item not found,
  // - -2 if not enough stock to reduce.
  static Future<int> reduceInventoryStockIfAvailable(
    String id,
    int amount,
  ) async {
    final box = inventoryProducts();
    final existing = box.get(id);
    if (existing == null) return -1;
    if (amount <= 0) return existing.stockQuantity;
    if (existing.stockQuantity < amount) return -2;
    existing.stockQuantity -= amount;
    await box.put(existing.id, existing);
    return existing.stockQuantity;
  }

  static bool inventoryHasProduct(String id) {
    return inventoryProducts().containsKey(id);
  }
}
