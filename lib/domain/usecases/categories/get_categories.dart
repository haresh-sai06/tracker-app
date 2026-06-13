import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/category.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/category_repository.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class GetCategories implements UseCase<List<Category>, NoParams> {
  final CategoryRepository repository;

  GetCategories(this.repository);

  @override
  Future<Either<Failure, List<Category>>> call(NoParams params) {
    return repository.getCategories();
  }
}
