import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/transaction_repository.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class GetTransactionsParams {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? categoryId;
  final String? accountId;
  final TransactionType? type;
  final String? searchQuery;
  final String? currencyCode;

  const GetTransactionsParams({
    this.startDate,
    this.endDate,
    this.categoryId,
    this.accountId,
    this.type,
    this.searchQuery,
    this.currencyCode,
  });
}

class GetTransactions implements UseCase<List<Transaction>, GetTransactionsParams> {
  final TransactionRepository repository;

  GetTransactions(this.repository);

  @override
  Future<Either<Failure, List<Transaction>>> call(GetTransactionsParams params) {
    return repository.getTransactions(
      startDate: params.startDate,
      endDate: params.endDate,
      categoryId: params.categoryId,
      accountId: params.accountId,
      type: params.type,
      searchQuery: params.searchQuery,
      currencyCode: params.currencyCode,
    );
  }
}
