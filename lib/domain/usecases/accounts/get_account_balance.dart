import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/account_balance.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/transaction_repository.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class GetAccountBalance implements UseCase<AccountBalance, String> {
  final TransactionRepository transactionRepository;

  GetAccountBalance(this.transactionRepository);

  @override
  Future<Either<Failure, AccountBalance>> call(String accountId) async {
    final result = await transactionRepository.getTransactions(accountId: accountId);
    return result.fold(
      (failure) => Left(failure),
      (transactions) {
        double totalCredits = 0.0;
        double totalDebits = 0.0;
        for (final tx in transactions) {
          if (tx.isDeleted) continue;
          if (tx.type == TransactionType.credit) {
            totalCredits += tx.amount;
          } else {
            totalDebits += tx.amount;
          }
        }
        return Right(AccountBalance(
          totalCredits: totalCredits,
          totalDebits: totalDebits,
          netBalance: totalCredits - totalDebits,
        ));
      },
    );
  }
}
