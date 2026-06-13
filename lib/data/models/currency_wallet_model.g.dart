// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency_wallet_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CurrencyWalletModelAdapter extends TypeAdapter<CurrencyWalletModel> {
  @override
  final int typeId = 7;

  @override
  CurrencyWalletModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CurrencyWalletModel(
      id: fields[0] as String?,
      currencyCode: fields[1] as String?,
      label: fields[2] as String?,
      isActive: fields[3] as bool?,
      createdAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, CurrencyWalletModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.currencyCode)
      ..writeByte(2)
      ..write(obj.label)
      ..writeByte(3)
      ..write(obj.isActive)
      ..writeByte(4)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurrencyWalletModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
