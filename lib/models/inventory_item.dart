import 'package:hive/hive.dart';

/// InventoryItem is a separate model used only for warehouse/inventory records.
/// We provide a manual TypeAdapter so it works without code generation.
class InventoryItem {
  String id;
  String name;
  double price;
  double? importPrice;
  String unit;
  int stockQuantity;

  InventoryItem({
    required this.id,
    required this.name,
    required this.price,
    this.importPrice,
    required this.unit,
    this.stockQuantity = 0,
  });

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: (json['barcode'] ?? json['id'] ?? json['inventory_item_id'])
          .toString(),
      name: (json['item_name'] ?? json['name'] ?? '').toString(),
      price: _toDouble(json['price']),
      importPrice: json['import_price'] == null && json['importPrice'] == null
          ? null
          : _toDouble(json['import_price'] ?? json['importPrice']),
      unit: (json['unit'] ?? 'sp').toString(),
      stockQuantity: _toInt(json['stock'] ?? json['stockQuantity']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'inventory_item_id': int.tryParse(id),
      'barcode': id,
      'item_name': name,
      'price': price,
      'import_price': importPrice,
      'unit': unit,
      'stock': stockQuantity,
    };
  }
}

class InventoryItemAdapter extends TypeAdapter<InventoryItem> {
  @override
  final int typeId = 10; // pick an id unlikely to collide

  @override
  InventoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      final key = reader.readByte();
      final value = reader.read();
      fields[key] = value;
    }

    return InventoryItem(
      id: fields[0].toString(),
      name: fields[1].toString(),
      price: (fields[2] as num).toDouble(),
      unit: fields[3].toString(),
      stockQuantity: (fields[4] as num).toInt(),
      importPrice: fields[5] == null ? null : (fields[5] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, InventoryItem obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.unit)
      ..writeByte(4)
      ..write(obj.stockQuantity)
      ..writeByte(5)
      ..write(obj.importPrice);
  }
}
