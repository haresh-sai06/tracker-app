import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/category.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/category_repository.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class AddCategory implements UseCase<void, Category> {
  final CategoryRepository repository;

  AddCategory(this.repository);

  @override
  Future<Either<Failure, void>> call(Category params) {
    return repository.addCategory(params);
  }
}
