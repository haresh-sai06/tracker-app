import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/monthly_summary.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/transaction_repository.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class GetMonthlySummaryParams {
  final DateTime month;
  final String? accountId;

  const GetMonthlySummaryParams({
    required this.month,
    this.accountId,
  });
}

class GetMonthlySummary implements UseCase<MonthlySummary, GetMonthlySummaryParams> {
  final TransactionRepository repository;

  GetMonthlySummary(this.repository);

  @override
  Future<Either<Failure, MonthlySummary>> call(GetMonthlySummaryParams params) async {
    final startDate = DateTime(params.month.year, params.month.month, 1);
    final endDate = DateTime(params.month.year, params.month.month + 1, 1).subtract(const Duration(microseconds: 1));

    final result = await repository.getTransactions(
      startDate: startDate,
      endDate: endDate,
      accountId: params.accountId,
    );

    return result.fold(
      (failure) => Left(failure),
      (transactions) {
        double totalCredits = 0.0;
        double totalDebits = 0.0;
        int transactionCount = 0;

        for (final tx in transactions) {
          if (tx.isDeleted) continue;
          if (tx.type == TransactionType.credit) {
            totalCredits += tx.amount;
          } else {
            totalDebits += tx.amount;
          }
          transactionCount++;
        }

        return Right(MonthlySummary(
          totalCredits: totalCredits,
          totalDebits: totalDebits,
          netChange: totalCredits - totalDebits,
          transactionCount: transactionCount,
        ));
      },
    );
  }
}
