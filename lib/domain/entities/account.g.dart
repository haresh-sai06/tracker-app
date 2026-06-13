// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AccountImpl _$$AccountImplFromJson(Map<String, dynamic> json) =>
    _$AccountImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      currencyCode: json['currencyCode'] as String? ?? 'INR',
      type: $enumDecode(_$AccountTypeEnumMap, json['type']),
      bankName: json['bankName'] as String?,
      lastFourDigits: json['lastFourDigits'] as String?,
      isDefault: json['isDefault'] as bool,
      isDeleted: json['isDeleted'] as bool,
    );

Map<String, dynamic> _$$AccountImplToJson(_$AccountImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'currencyCode': instance.currencyCode,
      'type': _$AccountTypeEnumMap[instance.type]!,
      'bankName': instance.bankName,
      'lastFourDigits': instance.lastFourDigits,
      'isDefault': instance.isDefault,
      'isDeleted': instance.isDeleted,
    };

const _$AccountTypeEnumMap = {
  AccountType.bank: 'bank',
  AccountType.wallet: 'wallet',
  AccountType.cash: 'cash',
  AccountType.credit: 'credit',
};
