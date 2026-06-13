// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SettingsModelAdapter extends TypeAdapter<SettingsModel> {
  @override
  final int typeId = 6;

  @override
  SettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SettingsModel(
      isBiometricEnabled: fields[0] as bool?,
      isSmsParsingEnabled: fields[1] as bool?,
      isNotificationListenerEnabled: fields[2] as bool?,
      isGmailSyncEnabled: fields[3] as bool?,
      defaultAccountId: fields[4] as String?,
      defaultCurrencyCode: fields[5] as String?,
      themeMode: fields[6] as String?,
      version: fields[7] as int?,
      userName: fields[8] as String?,
      userPhotoPath: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SettingsModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.isBiometricEnabled)
      ..writeByte(1)
      ..write(obj.isSmsParsingEnabled)
      ..writeByte(2)
      ..write(obj.isNotificationListenerEnabled)
      ..writeByte(3)
      ..write(obj.isGmailSyncEnabled)
      ..writeByte(4)
      ..write(obj.defaultAccountId)
      ..writeByte(5)
      ..write(obj.defaultCurrencyCode)
      ..writeByte(6)
      ..write(obj.themeMode)
      ..writeByte(7)
      ..write(obj.version)
      ..writeByte(8)
      ..write(obj.userName)
      ..writeByte(9)
      ..write(obj.userPhotoPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
