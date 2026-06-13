// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency_wallet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CurrencyWalletImpl _$$CurrencyWalletImplFromJson(Map<String, dynamic> json) =>
    _$CurrencyWalletImpl(
      id: json['id'] as String,
      currencyCode: json['currencyCode'] as String,
      label: json['label'] as String,
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$CurrencyWalletImplToJson(
        _$CurrencyWalletImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'currencyCode': instance.currencyCode,
      'label': instance.label,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt.toIso8601String(),
    };
