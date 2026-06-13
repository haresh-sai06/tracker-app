import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/account.dart';
import 'package:tracker_app/domain/failures/failure.dart';

abstract class AccountRepository {
  Future<Either<Failure, List<Account>>> getAccounts({String? currencyCode});
  Future<Either<Failure, Account>> getAccount(String id);
  Future<Either<Failure, void>> addAccount(Account account);
  Future<Either<Failure, void>> updateAccount(Account account);
  Future<Either<Failure, void>> deleteAccount(String id);
}
