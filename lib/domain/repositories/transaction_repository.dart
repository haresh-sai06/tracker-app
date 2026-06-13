import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/failures/failure.dart';

abstract class TransactionRepository {
  Future<Either<Failure, List<Transaction>>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? accountId,
    TransactionType? type,
    String? searchQuery,
    String? currencyCode,
  });
  Future<Either<Failure, Transaction>> getTransaction(String id);
  Future<Either<Failure, void>> addTransaction(Transaction transaction);
  Future<Either<Failure, void>> updateTransaction(Transaction transaction);
  Future<Either<Failure, void>> deleteTransaction(String id);
  Future<Either<Failure, List<Transaction>>> getTransactionsByCurrency(String currencyCode);
}
