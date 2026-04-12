import 'package:hive/hive.dart';

/// InventoryItem is a separate model used only for warehouse/inventory records.
/// We provide a manual TypeAdapter so it works without code generation.
class InventoryItem {
  String id;
  String name;
  double price;
  String unit;
  int stockQuantity;

  InventoryItem({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
    this.stockQuantity = 0,
  });
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
      id: fields[0] as String,
      name: fields[1] as String,
      price: (fields[2] as num).toDouble(),
      unit: fields[3] as String,
      stockQuantity: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, InventoryItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.unit)
      ..writeByte(4)
      ..write(obj.stockQuantity);
  }
}
