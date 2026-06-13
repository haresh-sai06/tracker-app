// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AccountModelAdapter extends TypeAdapter<AccountModel> {
  @override
  final int typeId = 4;

  @override
  AccountModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AccountModel(
      id: fields[0] as String?,
      name: fields[1] as String?,
      currencyCode: fields[7] as String?,
      type: fields[2] as HiveAccountType?,
      bankName: fields[3] as String?,
      lastFourDigits: fields[4] as String?,
      isDefault: fields[5] as bool?,
      isDeleted: fields[6] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, AccountModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.bankName)
      ..writeByte(4)
      ..write(obj.lastFourDigits)
      ..writeByte(5)
      ..write(obj.isDefault)
      ..writeByte(6)
      ..write(obj.isDeleted)
      ..writeByte(7)
      ..write(obj.currencyCode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveAccountTypeAdapter extends TypeAdapter<HiveAccountType> {
  @override
  final int typeId = 5;

  @override
  HiveAccountType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return HiveAccountType.bank;
      case 1:
        return HiveAccountType.wallet;
      case 2:
        return HiveAccountType.cash;
      case 3:
        return HiveAccountType.credit;
      default:
        return HiveAccountType.bank;
    }
  }

  @override
  void write(BinaryWriter writer, HiveAccountType obj) {
    switch (obj) {
      case HiveAccountType.bank:
        writer.writeByte(0);
        break;
      case HiveAccountType.wallet:
        writer.writeByte(1);
        break;
      case HiveAccountType.cash:
        writer.writeByte(2);
        break;
      case HiveAccountType.credit:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveAccountTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
