import 'package:hive/hive.dart';

part 'transaction_model.g.dart';

@HiveType(typeId: 1)
enum HiveTransactionType {
  @HiveField(0)
  credit,
  @HiveField(1)
  debit,
}

@HiveType(typeId: 2)
enum HiveTransactionSource {
  @HiveField(0)
  manual,
  @HiveField(1)
  sms,
  @HiveField(2)
  notification,
  @HiveField(3)
  email,
}

@HiveType(typeId: 0)
class TransactionModel extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  double? amount;

  @HiveField(2)
  HiveTransactionType? type;

  @HiveField(3)
  String? category;

  @HiveField(4)
  String? accountId;

  @HiveField(5)
  String? description;

  @HiveField(6)
  String? merchantName;

  @HiveField(7)
  HiveTransactionSource? source;

  @HiveField(8)
  String? rawSourceText;

  @HiveField(9)
  DateTime? dateTime;

  @HiveField(10)
  bool? isDeleted;

  @HiveField(11)
  DateTime? createdAt;

  @HiveField(12)
  DateTime? updatedAt;

  @HiveField(13)
  String? currencyCode;

  TransactionModel({
    this.id,
    this.amount,
    this.currencyCode,
    this.type,
    this.category,
    this.accountId,
    this.description,
    this.merchantName,
    this.source,
    this.rawSourceText,
    this.dateTime,
    this.isDeleted,
    this.createdAt,
    this.updatedAt,
  });
}
