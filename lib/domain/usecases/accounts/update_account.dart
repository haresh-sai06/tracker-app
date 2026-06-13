import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/account.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/account_repository.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class UpdateAccount implements UseCase<void, Account> {
  final AccountRepository repository;

  UpdateAccount(this.repository);

  @override
  Future<Either<Failure, void>> call(Account params) {
    return repository.updateAccount(params);
  }
}
