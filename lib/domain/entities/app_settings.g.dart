// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppSettingsImpl _$$AppSettingsImplFromJson(Map<String, dynamic> json) =>
    _$AppSettingsImpl(
      isBiometricEnabled: json['isBiometricEnabled'] as bool,
      isSmsParsingEnabled: json['isSmsParsingEnabled'] as bool,
      isNotificationListenerEnabled:
          json['isNotificationListenerEnabled'] as bool,
      isGmailSyncEnabled: json['isGmailSyncEnabled'] as bool,
      defaultAccountId: json['defaultAccountId'] as String?,
      defaultCurrencyCode: json['defaultCurrencyCode'] as String,
      themeMode: json['themeMode'] as String,
      userName: json['userName'] as String?,
      userPhotoPath: json['userPhotoPath'] as String?,
    );

Map<String, dynamic> _$$AppSettingsImplToJson(_$AppSettingsImpl instance) =>
    <String, dynamic>{
      'isBiometricEnabled': instance.isBiometricEnabled,
      'isSmsParsingEnabled': instance.isSmsParsingEnabled,
      'isNotificationListenerEnabled': instance.isNotificationListenerEnabled,
      'isGmailSyncEnabled': instance.isGmailSyncEnabled,
      'defaultAccountId': instance.defaultAccountId,
      'defaultCurrencyCode': instance.defaultCurrencyCode,
      'themeMode': instance.themeMode,
      'userName': instance.userName,
      'userPhotoPath': instance.userPhotoPath,
    };
