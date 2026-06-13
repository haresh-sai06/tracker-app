import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/transaction_repository.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class AddTransaction implements UseCase<void, Transaction> {
  final TransactionRepository repository;

  AddTransaction(this.repository);

  @override
  Future<Either<Failure, void>> call(Transaction params) {
    return repository.addTransaction(params);
  }
}
