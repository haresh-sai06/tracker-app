import 'package:hive/hive.dart';

part 'account_model.g.dart';

@HiveType(typeId: 5)
enum HiveAccountType {
  @HiveField(0)
  bank,
  @HiveField(1)
  wallet,
  @HiveField(2)
  cash,
  @HiveField(3)
  credit,
}

@HiveType(typeId: 4)
class AccountModel extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String? name;

  @HiveField(2)
  HiveAccountType? type;

  @HiveField(3)
  String? bankName;

  @HiveField(4)
  String? lastFourDigits;

  @HiveField(5)
  bool? isDefault;

  @HiveField(6)
  bool? isDeleted;

  @HiveField(7)
  String? currencyCode;

  AccountModel({
    this.id,
    this.name,
    this.currencyCode,
    this.type,
    this.bankName,
    this.lastFourDigits,
    this.isDefault,
    this.isDeleted,
  });
}
