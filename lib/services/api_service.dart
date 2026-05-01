import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/order.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../models/inventory_item.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  static const Duration _timeout = Duration(seconds: 5);

  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  static dynamic _decode(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 400) {
      final message = body is Map && body['message'] != null
          ? body['message'].toString()
          : 'Lỗi API ${response.statusCode}';
      throw ApiException(message);
    }
    if (body is Map && body['success'] == false) {
      throw ApiException((body['message'] ?? 'API trả về lỗi').toString());
    }
    return body;
  }

  static List<dynamic> _dataList(dynamic body) {
    if (body is Map && body['data'] is List) return body['data'] as List;
    if (body is List) return body;
    return const [];
  }

  static Map<String, dynamic> _dataMap(dynamic body) {
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    if (body is Map) return Map<String, dynamic>.from(body);
    return <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      _uri('/api/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(_timeout);
    final body = _decode(response);
    return Map<String, dynamic>.from((body as Map)['user'] as Map);
  }

  static Future<void> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    String? address,
  }) async {
    final response = await http.post(
      _uri('/api/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'password': password,
        'phone': phone,
        'address': address,
      }),
    ).timeout(_timeout);
    _decode(response);
  }

  static Future<List<User>> fetchUsers() async {
    final response = await http.get(_uri('/api/users')).timeout(_timeout);
    final body = _decode(response);
    return _dataList(body)
        .map((e) => User.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<User> createUser(User user) async {
    final response = await http.post(
      _uri('/api/users'),
      headers: _headers,
      body: jsonEncode(user.toJson()),
    ).timeout(_timeout);
    final body = _decode(response);
    return User.fromJson(_dataMap(body));
  }

  static Future<User> updateUser(int userId, User user) async {
    final response = await http.put(
      _uri('/api/users/$userId'),
      headers: _headers,
      body: jsonEncode(user.toJson()),
    ).timeout(_timeout);
    final body = _decode(response);
    return User.fromJson(_dataMap(body));
  }

  static Future<void> deleteUser(int userId) async {
    final response = await http.delete(_uri('/api/users/$userId')).timeout(_timeout);
    _decode(response);
  }

  static Future<List<Map<String, dynamic>>> fetchCategories() async {
    final response = await http.get(_uri('/api/categories')).timeout(_timeout);
    final body = _decode(response);
    return _dataList(body)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> createCategory(String name) async {
    final response = await http.post(
      _uri('/api/categories'),
      headers: _headers,
      body: jsonEncode({'category_name': name}),
    ).timeout(_timeout);
    return _dataMap(_decode(response));
  }

  static Future<List<Product>> fetchProducts() async {
    final response = await http.get(_uri('/api/products')).timeout(_timeout);
    final body = _decode(response);
    return _dataList(body)
        .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<Product> createProduct(Product product) async {
    final response = await http.post(
      _uri('/api/products'),
      headers: _headers,
      body: jsonEncode(product.toJson()),
    ).timeout(_timeout);
    return Product.fromJson(_dataMap(_decode(response)));
  }

  static Future<Product> updateProduct(Product product) async {
    final response = await http.put(
      _uri('/api/products/${product.id}'),
      headers: _headers,
      body: jsonEncode(product.toJson()),
    ).timeout(_timeout);
    return Product.fromJson(_dataMap(_decode(response)));
  }

  static Future<void> deleteProduct(String productId) async {
    final response = await http.delete(_uri('/api/products/$productId')).timeout(_timeout);
    _decode(response);
  }

  static Future<String> uploadProductImage(String filePath) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/uploads/product-image'),
    );
    request.files.add(await http.MultipartFile.fromPath('image', filePath));
    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    return _dataMap(_decode(response))['image_url'].toString();
  }

  static Future<List<Order>> fetchOrders() async {
    final response = await http.get(_uri('/api/orders')).timeout(_timeout);
    final body = _decode(response);
    return _dataList(body)
        .map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<Order> createOrder(Order order, {int? customerId, int? employeeId}) async {
    final response = await http.post(
      _uri('/api/orders'),
      headers: _headers,
      body: jsonEncode(order.toJson(customerId: customerId, employeeId: employeeId)),
    ).timeout(_timeout);
    return Order.fromJson(_dataMap(_decode(response)));
  }

  static Future<List<Map<String, dynamic>>> fetchInventoryLogs() async {
    final response = await http.get(_uri('/api/inventory/logs')).timeout(_timeout);
    final body = _decode(response);
    return _dataList(body)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<List<InventoryItem>> fetchInventoryItems() async {
    final response = await http.get(_uri('/api/inventory/items')).timeout(_timeout);
    final body = _decode(response);
    return _dataList(body)
        .map((e) => InventoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<InventoryItem> createInventoryItem(InventoryItem item) async {
    final response = await http.post(
      _uri('/api/inventory/items'),
      headers: _headers,
      body: jsonEncode(item.toJson()),
    ).timeout(_timeout);
    return InventoryItem.fromJson(_dataMap(_decode(response)));
  }

  static Future<InventoryItem> updateInventoryItem(InventoryItem item) async {
    final response = await http.put(
      _uri('/api/inventory/items/${item.id}'),
      headers: _headers,
      body: jsonEncode(item.toJson()),
    ).timeout(_timeout);
    return InventoryItem.fromJson(_dataMap(_decode(response)));
  }

  static Future<void> importInventory({
    required String inventoryItemId,
    required int employeeId,
    required int quantity,
    String? note,
  }) async {
    final response = await http.post(
      _uri('/api/inventory/import'),
      headers: _headers,
      body: jsonEncode({
        'inventory_item_id': inventoryItemId,
        'employee_id': employeeId,
        'quantity': quantity,
        'note': note,
      }),
    ).timeout(_timeout);
    _decode(response);
  }

  static Future<void> adjustInventory({
    required String inventoryItemId,
    required int employeeId,
    required int actualQuantity,
    String? note,
  }) async {
    final response = await http.post(
      _uri('/api/inventory/adjust'),
      headers: _headers,
      body: jsonEncode({
        'inventory_item_id': inventoryItemId,
        'employee_id': employeeId,
        'actual_quantity': actualQuantity,
        'note': note,
      }),
    ).timeout(_timeout);
    _decode(response);
  }

  static Future<void> exportInventory({
    required String inventoryItemId,
    String? productId,
    required int employeeId,
    required int quantity,
    String? note,
  }) async {
    final response = await http.post(
      _uri('/api/inventory/export'),
      headers: _headers,
      body: jsonEncode({
        'inventory_item_id': inventoryItemId,
        'product_id': productId == null ? null : int.tryParse(productId),
        'employee_id': employeeId,
        'quantity': quantity,
        'note': note,
      }),
    ).timeout(_timeout);
    _decode(response);
  }

  static Future<Map<String, int>> fetchCart(int userId) async {
    final response = await http.get(_uri('/api/carts/$userId')).timeout(_timeout);
    final body = _dataMap(_decode(response));
    final items = (body['items'] as List?) ?? const [];
    return {
      for (final item in items)
        (item as Map)['product_id'].toString(): (item['quantity'] ?? 0) as int,
    };
  }

  static Future<void> saveCart(int userId, Map<String, int> cart) async {
    final response = await http.put(
      _uri('/api/carts/$userId'),
      headers: _headers,
      body: jsonEncode({
        'items': cart.entries
            .where((entry) => entry.value > 0)
            .map((entry) => {
                  'product_id': int.parse(entry.key),
                  'quantity': entry.value,
                })
            .toList(),
      }),
    ).timeout(_timeout);
    _decode(response);
  }
}
