import 'package:intl/intl.dart';
import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/analytics_entities.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/transaction_repository.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class GetMonthlyTrendParams {
  final int lastNMonths;
  final String? currencyCode;

  const GetMonthlyTrendParams({
    required this.lastNMonths,
    this.currencyCode,
  });
}

class GetMonthlyTrend implements UseCase<List<MonthlyTrend>, GetMonthlyTrendParams> {
  final TransactionRepository repository;

  GetMonthlyTrend(this.repository);

  @override
  Future<Either<Failure, List<MonthlyTrend>>> call(GetMonthlyTrendParams params) async {
    final List<MonthlyTrend> trends = [];

    for (int i = params.lastNMonths - 1; i >= 0; i--) {
      final now = DateTime.now();
      final date = DateTime(now.year, now.month - i, 1);
      final startDate = date;
      final endDate = DateTime(date.year, date.month + 1, 1).subtract(const Duration(microseconds: 1));

      final result = await repository.getTransactions(
        startDate: startDate,
        endDate: endDate,
        currencyCode: params.currencyCode,
      );

      final errorOrNull = result.fold((failure) => failure, (_) => null);
      if (errorOrNull != null) {
        return Left(errorOrNull);
      }

      final transactions = result.fold((_) => <Transaction>[], (txList) => txList);
      double totalCredits = 0.0;
      double totalDebits = 0.0;

      for (final tx in transactions) {
        if (tx.isDeleted) continue;
        if (tx.type == TransactionType.credit) {
          totalCredits += tx.amount;
        } else if (tx.type == TransactionType.debit) {
          totalDebits += tx.amount;
        }
      }

      final monthStr = DateFormat('MMM yy').format(date);
      trends.add(MonthlyTrend(
        month: monthStr,
        date: date,
        totalCredits: totalCredits,
        totalDebits: totalDebits,
      ));
    }

    return Right(trends);
  }
}
