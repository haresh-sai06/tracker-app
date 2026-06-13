import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/category_repository.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class DeleteCategory implements UseCase<void, String> {
  final CategoryRepository repository;

  DeleteCategory(this.repository);

  @override
  Future<Either<Failure, void>> call(String params) {
    return repository.deleteCategory(params);
  }
}
