/// Centralized constants for the application
/// Avoids duplication of constant values across screens

class AppConstants {
  // Inventory constants
  static const int minStockThreshold = 50;

  // API timeout
  static const int apiTimeoutSeconds = 5;
  static const int checkoutTimeoutSeconds = 12;

  // Hive box names
  static const String productsBox = 'products';
  static const String usersBox = 'users';
  static const String ordersBox = 'orders';
  static const String settingsBox = 'settings';
  static const String cartsBox = 'carts';
  static const String productImagesBox = 'product_images';
  static const String inventoryProductsBox = 'inventory_products';
  static const String inventoryHistoryBox = 'inventory_history_box';

  // Cache schema
  static const int cacheSchemaVersion = 3;
  static const bool forceUseLocalProductSeed = false;
}
