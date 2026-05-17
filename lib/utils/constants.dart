/// Centralized constants for the application
/// Avoids duplication of constant values across screens

class AppConstants {
  // Inventory constants
  static const int minStockThreshold = 50;

  // API timeout
  static const int apiTimeoutSeconds = 5;
  static const int shiftTimeoutSeconds = 15;
  static const int checkoutTimeoutSeconds = 12;

  /// Điện thoại thật: đặt IP máy tính chạy backend (cùng Wi‑Fi), ví dụ http://192.168.1.10:3000
  /// Máy ảo Android: để null (app dùng http://10.0.2.2:3000)
  static const String? apiBaseUrlOverride = null;

  // Hive box names
  static const String productsBox = 'products';
  static const String usersBox = 'users';
  static const String ordersBox = 'orders';
  static const String settingsBox = 'settings';
  static const String cartsBox = 'carts';
  static const String productImagesBox = 'product_images';
  static const String inventoryProductsBox = 'inventory_products';
  static const String inventoryHistoryBox = 'inventory_history_box';
  static const String workShiftSummariesBox = 'work_shift_summaries';

  // Cache schema
  static const int cacheSchemaVersion = 3;
  static const bool forceUseLocalProductSeed = false;
}
