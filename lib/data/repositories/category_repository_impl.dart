import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/category.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/category_repository.dart';
import 'package:tracker_app/data/models/category_model.dart';
import 'package:tracker_app/data/services/database_service.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  @override
  Future<Either<Failure, List<Category>>> getCategories() async {
    try {
      final box = DatabaseService.categoriesBox;
      final list = box.values
          .where((m) => m.isDeleted != true)
          .map((m) => _toEntity(m))
          .toList();
      return Right(list);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Category>> getCategory(String id) async {
    try {
      final box = DatabaseService.categoriesBox;
      final model = box.get(id);
      if (model == null || model.isDeleted == true) {
        return const Left(NotFoundFailure('Category not found'));
      }
      return Right(_toEntity(model));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addCategory(Category category) async {
    try {
      final box = DatabaseService.categoriesBox;
      await box.put(category.id, _toModel(category));
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateCategory(Category category) async {
    try {
      final box = DatabaseService.categoriesBox;
      await box.put(category.id, _toModel(category));
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCategory(String id) async {
    try {
      final box = DatabaseService.categoriesBox;
      final model = box.get(id);
      if (model != null) {
        model.isDeleted = true;
        await model.save();
      }
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  Category _toEntity(CategoryModel model) {
    return Category(
      id: model.id ?? '',
      name: model.name ?? '',
      iconCodePoint: model.iconCodePoint ?? 0,
      colorValue: model.colorValue ?? 0,
      isDefault: model.isDefault ?? false,
      isDeleted: model.isDeleted ?? false,
    );
  }

  CategoryModel _toModel(Category entity) {
    return CategoryModel(
      id: entity.id,
      name: entity.name,
      iconCodePoint: entity.iconCodePoint,
      colorValue: entity.colorValue,
      isDefault: entity.isDefault,
      isDeleted: entity.isDeleted,
    );
  }
}
