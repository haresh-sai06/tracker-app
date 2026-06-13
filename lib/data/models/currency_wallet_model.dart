import 'package:hive/hive.dart';

part 'currency_wallet_model.g.dart';

@HiveType(typeId: 7)
class CurrencyWalletModel extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String? currencyCode;

  @HiveField(2)
  String? label;

  @HiveField(3)
  bool? isActive;

  @HiveField(4)
  DateTime? createdAt;

  CurrencyWalletModel({
    this.id,
    this.currencyCode,
    this.label,
    this.isActive,
    this.createdAt,
  });
}
