import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/transaction_repository.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class DeleteTransaction implements UseCase<void, String> {
  final TransactionRepository repository;

  DeleteTransaction(this.repository);

  @override
  Future<Either<Failure, void>> call(String params) {
    return repository.deleteTransaction(params);
  }
}
