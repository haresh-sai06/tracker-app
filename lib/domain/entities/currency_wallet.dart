import 'package:freezed_annotation/freezed_annotation.dart';

part 'currency_wallet.freezed.dart';
part 'currency_wallet.g.dart';

@freezed
class CurrencyWallet with _$CurrencyWallet {
  const factory CurrencyWallet({
    required String id,
    required String currencyCode,
    required String label,
    required bool isActive,
    required DateTime createdAt,
  }) = _CurrencyWallet;

  factory CurrencyWallet.fromJson(Map<String, dynamic> json) => _$CurrencyWalletFromJson(json);
}
