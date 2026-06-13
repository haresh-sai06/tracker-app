import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/account.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/account_repository.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class GetAccounts implements UseCase<List<Account>, String?> {
  final AccountRepository repository;

  GetAccounts(this.repository);

  @override
  Future<Either<Failure, List<Account>>> call(String? currencyCode) {
    return repository.getAccounts(currencyCode: currencyCode);
  }
}
