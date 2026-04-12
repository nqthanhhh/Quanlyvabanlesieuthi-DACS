// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OrderAdapter extends TypeAdapter<Order> {
  @override
  final int typeId = 2;

  @override
  Order read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Order(
      id: fields[0] as String,
      orderDate: fields[1] as DateTime,
      totalAmount: fields[2] as double,
      customerName: fields[3] as String,
      status: fields[4] as String,
      items: (fields[5] as List).cast<OrderLine>(),
    );
  }

  @override
  void write(BinaryWriter writer, Order obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.orderDate)
      ..writeByte(2)
      ..write(obj.totalAmount)
      ..writeByte(3)
      ..write(obj.customerName)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.items);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
