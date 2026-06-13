// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionModelAdapter extends TypeAdapter<TransactionModel> {
  @override
  final int typeId = 0;

  @override
  TransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionModel(
      id: fields[0] as String?,
      amount: fields[1] as double?,
      currencyCode: fields[13] as String?,
      type: fields[2] as HiveTransactionType?,
      category: fields[3] as String?,
      accountId: fields[4] as String?,
      description: fields[5] as String?,
      merchantName: fields[6] as String?,
      source: fields[7] as HiveTransactionSource?,
      rawSourceText: fields[8] as String?,
      dateTime: fields[9] as DateTime?,
      isDeleted: fields[10] as bool?,
      createdAt: fields[11] as DateTime?,
      updatedAt: fields[12] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.accountId)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.merchantName)
      ..writeByte(7)
      ..write(obj.source)
      ..writeByte(8)
      ..write(obj.rawSourceText)
      ..writeByte(9)
      ..write(obj.dateTime)
      ..writeByte(10)
      ..write(obj.isDeleted)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt)
      ..writeByte(13)
      ..write(obj.currencyCode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveTransactionTypeAdapter extends TypeAdapter<HiveTransactionType> {
  @override
  final int typeId = 1;

  @override
  HiveTransactionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return HiveTransactionType.credit;
      case 1:
        return HiveTransactionType.debit;
      default:
        return HiveTransactionType.credit;
    }
  }

  @override
  void write(BinaryWriter writer, HiveTransactionType obj) {
    switch (obj) {
      case HiveTransactionType.credit:
        writer.writeByte(0);
        break;
      case HiveTransactionType.debit:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveTransactionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveTransactionSourceAdapter extends TypeAdapter<HiveTransactionSource> {
  @override
  final int typeId = 2;

  @override
  HiveTransactionSource read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return HiveTransactionSource.manual;
      case 1:
        return HiveTransactionSource.sms;
      case 2:
        return HiveTransactionSource.notification;
      case 3:
        return HiveTransactionSource.email;
      default:
        return HiveTransactionSource.manual;
    }
  }

  @override
  void write(BinaryWriter writer, HiveTransactionSource obj) {
    switch (obj) {
      case HiveTransactionSource.manual:
        writer.writeByte(0);
        break;
      case HiveTransactionSource.sms:
        writer.writeByte(1);
        break;
      case HiveTransactionSource.notification:
        writer.writeByte(2);
        break;
      case HiveTransactionSource.email:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveTransactionSourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
