import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/account_repository.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class DeleteAccount implements UseCase<void, String> {
  final AccountRepository repository;

  DeleteAccount(this.repository);

  @override
  Future<Either<Failure, void>> call(String params) {
    return repository.deleteAccount(params);
  }
}
