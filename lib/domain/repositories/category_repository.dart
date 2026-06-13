import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/category.dart';
import 'package:tracker_app/domain/failures/failure.dart';

abstract class CategoryRepository {
  Future<Either<Failure, List<Category>>> getCategories();
  Future<Either<Failure, Category>> getCategory(String id);
  Future<Either<Failure, void>> addCategory(Category category);
  Future<Either<Failure, void>> updateCategory(Category category);
  Future<Either<Failure, void>> deleteCategory(String id);
}
