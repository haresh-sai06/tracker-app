import 'package:flutter/foundation.dart';
import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/analytics_entities.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/transaction_repository.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class GetTopMerchantsParams {
  final DateTime startDate;
  final DateTime endDate;
  final int limit;
  final String? currencyCode;

  const GetTopMerchantsParams({
    required this.startDate,
    required this.endDate,
    required this.limit,
    this.currencyCode,
  });
}

// Top level static parameters dictionary input for compute task
class _TopMerchantsCompParams {
  final List<Transaction> transactions;
  final int limit;

  _TopMerchantsCompParams(this.transactions, this.limit);
}

// Top level worker function for isolative computing
List<TopMerchant> _computeTopMerchants(_TopMerchantsCompParams params) {
  final Map<String, double> totals = {};
  final Map<String, int> counts = {};
  final Map<String, String> displayNameMap = {};

  for (final tx in params.transactions) {
    if (tx.isDeleted) continue;
    if (tx.type == TransactionType.debit) {
      final name = tx.merchantName?.trim();
      if (name == null || name.isEmpty) continue;

      final lowercaseName = name.toLowerCase();
      totals[lowercaseName] = (totals[lowercaseName] ?? 0.0) + tx.amount;
      counts[lowercaseName] = (counts[lowercaseName] ?? 0) + 1;
      
      if (!displayNameMap.containsKey(lowercaseName)) {
        displayNameMap[lowercaseName] = name;
      }
    }
  }

  final List<TopMerchant> merchants = [];
  totals.forEach((key, total) {
    merchants.add(TopMerchant(
      merchantName: displayNameMap[key] ?? key,
      total: total,
      count: counts[key] ?? 1,
    ));
  });

  // Sort by total descending
  merchants.sort((a, b) => b.total.compareTo(a.total));

  // Limit the results
  return merchants.take(params.limit).toList();
}

class GetTopMerchants implements UseCase<List<TopMerchant>, GetTopMerchantsParams> {
  final TransactionRepository repository;

  GetTopMerchants(this.repository);

  @override
  Future<Either<Failure, List<TopMerchant>>> call(GetTopMerchantsParams params) async {
    final result = await repository.getTransactions(
       startDate: params.startDate,
       endDate: params.endDate,
       currencyCode: params.currencyCode,
    );

    return result.fold(
      (failure) => Left(failure),
      (transactions) async {
        final compParams = _TopMerchantsCompParams(transactions, params.limit);
        
        if (transactions.length > 50) {
          final computed = await compute(_computeTopMerchants, compParams);
          return Right(computed);
        } else {
          final computed = _computeTopMerchants(compParams);
          return Right(computed);
        }
      },
    );
  }
}
