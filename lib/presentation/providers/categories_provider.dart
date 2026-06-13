import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tracker_app/domain/entities/category.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';
import 'package:tracker_app/domain/usecases/categories/get_categories.dart';
import 'package:tracker_app/domain/usecases/categories/add_category.dart';
import 'package:tracker_app/domain/usecases/categories/update_category.dart';
import 'package:tracker_app/domain/usecases/categories/delete_category.dart';
import 'package:tracker_app/presentation/providers/repository_providers.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';
import 'package:tracker_app/core/services/auto_sync_service.dart';

part 'categories_provider.g.dart';

@riverpod
class CategoriesNotifier extends _$CategoriesNotifier {
  late GetCategories _getCategories;
  late AddCategory _addCategory;
  late UpdateCategory _updateCategory;
  late DeleteCategory _deleteCategory;

  @override
  FutureOr<List<Category>> build() async {
    final repository = ref.watch(categoryRepositoryProvider);
    _getCategories = GetCategories(repository);
    _addCategory = AddCategory(repository);
    _updateCategory = UpdateCategory(repository);
    _deleteCategory = DeleteCategory(repository);

    return _loadCategories();
  }

  Future<List<Category>> _loadCategories() async {
    final result = await _getCategories.call(const NoParams());
    return result.fold(
      (failure) => throw failure,
      (categories) => categories,
    );
  }

  Future<void> add(Category category) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _addCategory.call(category);
      return result.fold(
        (failure) => throw failure,
        (_) {
          ref.read(autoSyncServiceProvider).scheduleSync();
          return _loadCategories();
        },
      );
    });
  }

  Future<void> updateCat(Category category) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _updateCategory.call(category);
      return result.fold(
        (failure) => throw failure,
        (_) {
          ref.read(autoSyncServiceProvider).scheduleSync();
          return _loadCategories();
        },
      );
    });
  }

  Future<bool> deleteCat(String id) async {
    // Check if any active transactions are using this category ID
    final transactionsAsync = ref.read(transactionsNotifierProvider);
    final transactions = transactionsAsync.valueOrNull ?? [];
    
    final categoryUsed = transactions.any((tx) => tx.category == id && !tx.isDeleted);
    if (categoryUsed) {
      throw Exception('Cannot delete a category that has transactions associated with it.');
    }

    state = const AsyncValue.loading();
    var success = false;
    state = await AsyncValue.guard(() async {
      final result = await _deleteCategory.call(id);
      return result.fold(
        (failure) => throw failure,
        (_) {
          success = true;
          ref.read(autoSyncServiceProvider).scheduleSync();
          return _loadCategories();
        },
      );
    });
    return success;
  }
}
