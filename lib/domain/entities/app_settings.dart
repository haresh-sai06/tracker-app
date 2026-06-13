import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    required bool isBiometricEnabled,
    required bool isSmsParsingEnabled,
    required bool isNotificationListenerEnabled,
    required bool isGmailSyncEnabled,
    String? defaultAccountId,
    required String defaultCurrencyCode,
    required String themeMode,
    String? userName,
    String? userPhotoPath,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);
}
