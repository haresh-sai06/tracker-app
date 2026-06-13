import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/usecases/transactions/get_transactions.dart';
import 'package:tracker_app/domain/usecases/transactions/add_transaction.dart';
import 'package:tracker_app/domain/usecases/transactions/update_transaction.dart';
import 'package:tracker_app/domain/usecases/transactions/delete_transaction.dart';
import 'package:tracker_app/presentation/providers/repository_providers.dart';
import 'package:tracker_app/presentation/providers/wallets_provider.dart';
import 'package:tracker_app/core/services/auto_sync_service.dart';

part 'transactions_provider.g.dart';

@riverpod
class TransactionsNotifier extends _$TransactionsNotifier {
  GetTransactions get _getTransactions => GetTransactions(ref.read(transactionRepositoryProvider));
  AddTransaction get _addTransaction => AddTransaction(ref.read(transactionRepositoryProvider));
  UpdateTransaction get _updateTransaction => UpdateTransaction(ref.read(transactionRepositoryProvider));
  DeleteTransaction get _deleteTransaction => DeleteTransaction(ref.read(transactionRepositoryProvider));

  @override
  FutureOr<List<Transaction>> build() async {
    ref.watch(transactionRepositoryProvider);

    return _loadTransactions();
  }

  Future<List<Transaction>> _loadTransactions() async {
    final result = await _getTransactions.call(const GetTransactionsParams());
    return result.fold(
      (failure) => throw failure,
      (transactions) => transactions,
    );
  }

  Future<void> add(Transaction transaction) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _addTransaction.call(transaction);
      return result.fold(
        (failure) => throw failure,
        (_) {
          ref.read(autoSyncServiceProvider).scheduleSync();
          return _loadTransactions();
        },
      );
    });
  }

  Future<void> updateTx(Transaction transaction) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _updateTransaction.call(transaction);
      return result.fold(
        (failure) => throw failure,
        (_) {
          ref.read(autoSyncServiceProvider).scheduleSync();
          return _loadTransactions();
        },
      );
    });
  }

  Future<void> softDelete(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _deleteTransaction.call(id);
      return result.fold(
        (failure) => throw failure,
        (_) {
          ref.read(autoSyncServiceProvider).scheduleSync();
          return _loadTransactions();
        },
      );
    });
  }
}
