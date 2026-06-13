import 'package:flutter/foundation.dart';
import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/analytics_entities.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/transaction_repository.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class GetSpendingByCategoryParams {
  final DateTime startDate;
  final DateTime endDate;
  final String? currencyCode;

  const GetSpendingByCategoryParams({
    required this.startDate,
    required this.endDate,
    this.currencyCode,
  });
}

// Top level computation helper for Isolate offloading
List<CategorySpending> _computeSpendingByCategory(List<Transaction> transactions) {
  final Map<String, double> totals = {};
  double overallTotal = 0.0;

  for (final tx in transactions) {
    if (tx.isDeleted) continue;
    if (tx.type == TransactionType.debit) {
      totals[tx.category] = (totals[tx.category] ?? 0.0) + tx.amount;
      overallTotal += tx.amount;
    }
  }

  final List<CategorySpending> spendingList = [];
  if (overallTotal > 0) {
    totals.forEach((catId, total) {
      final percentage = (total / overallTotal) * 100;
      spendingList.add(CategorySpending(
        categoryId: catId,
        total: total,
        percentage: percentage,
      ));
    });
  } else {
    totals.forEach((catId, total) {
      spendingList.add(CategorySpending(
        categoryId: catId,
        total: total,
        percentage: 0.0,
      ));
    });
  }

  spendingList.sort((a, b) => b.total.compareTo(a.total));
  return spendingList;
}

class GetSpendingByCategory implements UseCase<List<CategorySpending>, GetSpendingByCategoryParams> {
  final TransactionRepository repository;

  GetSpendingByCategory(this.repository);

  @override
  Future<Either<Failure, List<CategorySpending>>> call(GetSpendingByCategoryParams params) async {
    final result = await repository.getTransactions(
      startDate: params.startDate,
      endDate: params.endDate,
      currencyCode: params.currencyCode,
    );

    return result.fold(
      (failure) => Left(failure),
      (transactions) async {
        // Run in isolate background thread via compute() if there are standard entries 
        // to prevent frame drops in UI
        if (transactions.length > 50) {
          final computed = await compute(_computeSpendingByCategory, transactions);
          return Right(computed);
        } else {
          final computed = _computeSpendingByCategory(transactions);
          return Right(computed);
        }
      },
    );
  }
}
