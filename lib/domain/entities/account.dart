import 'package:freezed_annotation/freezed_annotation.dart';

part 'account.freezed.dart';
part 'account.g.dart';

enum AccountType {
  bank,
  wallet,
  cash,
  credit,
}

@freezed
class Account with _$Account {
  const factory Account({
    required String id,
    required String name,
    @Default('INR') String currencyCode,
    required AccountType type,
    String? bankName,
    String? lastFourDigits,
    required bool isDefault,
    required bool isDeleted,
  }) = _Account; // wait, let's use _Account here to be correct! Let's edit this.
  
  factory Account.fromJson(Map<String, dynamic> json) => _$AccountFromJson(json);
}
