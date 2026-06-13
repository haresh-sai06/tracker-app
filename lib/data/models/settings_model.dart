import 'package:hive/hive.dart';

part 'settings_model.g.dart';

@HiveType(typeId: 6)
class SettingsModel extends HiveObject {
  @HiveField(0)
  bool? isBiometricEnabled;

  @HiveField(1)
  bool? isSmsParsingEnabled;

  @HiveField(2)
  bool? isNotificationListenerEnabled;

  @HiveField(3)
  bool? isGmailSyncEnabled;

  @HiveField(4)
  String? defaultAccountId;

  @HiveField(5)
  String? defaultCurrencyCode;

  @HiveField(6)
  String? themeMode;

  @HiveField(7)
  int? version;

  @HiveField(8)
  String? userName;

  @HiveField(9)
  String? userPhotoPath;

  SettingsModel({
    this.isBiometricEnabled,
    this.isSmsParsingEnabled,
    this.isNotificationListenerEnabled,
    this.isGmailSyncEnabled,
    this.defaultAccountId,
    this.defaultCurrencyCode,
    this.themeMode,
    this.version,
    this.userName,
    this.userPhotoPath,
  });
}
