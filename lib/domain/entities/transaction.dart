import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

enum TransactionType {
  credit,
  debit,
}

enum TransactionSource {
  manual,
  sms,
  notification,
  email,
}

@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    required double amount,
    @Default('INR') String currencyCode,
    required TransactionType type,
    required String category, // category id
    required String accountId,
    required String description,
    String? merchantName,
    required TransactionSource source,
    String? rawSourceText,
    required DateTime dateTime,
    required bool isDeleted,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) => _$TransactionFromJson(json);
}
