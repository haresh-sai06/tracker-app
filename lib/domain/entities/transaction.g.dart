// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TransactionImpl _$$TransactionImplFromJson(Map<String, dynamic> json) =>
    _$TransactionImpl(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currencyCode: json['currencyCode'] as String? ?? 'INR',
      type: $enumDecode(_$TransactionTypeEnumMap, json['type']),
      category: json['category'] as String,
      accountId: json['accountId'] as String,
      description: json['description'] as String,
      merchantName: json['merchantName'] as String?,
      source: $enumDecode(_$TransactionSourceEnumMap, json['source']),
      rawSourceText: json['rawSourceText'] as String?,
      dateTime: DateTime.parse(json['dateTime'] as String),
      isDeleted: json['isDeleted'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$TransactionImplToJson(_$TransactionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'amount': instance.amount,
      'currencyCode': instance.currencyCode,
      'type': _$TransactionTypeEnumMap[instance.type]!,
      'category': instance.category,
      'accountId': instance.accountId,
      'description': instance.description,
      'merchantName': instance.merchantName,
      'source': _$TransactionSourceEnumMap[instance.source]!,
      'rawSourceText': instance.rawSourceText,
      'dateTime': instance.dateTime.toIso8601String(),
      'isDeleted': instance.isDeleted,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$TransactionTypeEnumMap = {
  TransactionType.credit: 'credit',
  TransactionType.debit: 'debit',
};

const _$TransactionSourceEnumMap = {
  TransactionSource.manual: 'manual',
  TransactionSource.sms: 'sms',
  TransactionSource.notification: 'notification',
  TransactionSource.email: 'email',
};
