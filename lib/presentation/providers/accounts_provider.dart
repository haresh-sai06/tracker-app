import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tracker_app/domain/entities/account.dart';
import 'package:tracker_app/domain/entities/account_balance.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';
import 'package:tracker_app/domain/usecases/accounts/get_accounts.dart';
import 'package:tracker_app/domain/usecases/accounts/add_account.dart';
import 'package:tracker_app/domain/usecases/accounts/update_account.dart';
import 'package:tracker_app/domain/usecases/accounts/delete_account.dart';
import 'package:tracker_app/presentation/providers/repository_providers.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';
import 'package:tracker_app/presentation/providers/wallets_provider.dart';
import 'package:tracker_app/core/services/auto_sync_service.dart';
import 'package:tracker_app/core/utils/currency_utils.dart';

part 'accounts_provider.g.dart';

@riverpod
class AccountsNotifier extends _$AccountsNotifier {
  late GetAccounts _getAccounts;
  late AddAccount _addAccount;
  late UpdateAccount _updateAccount;
  late DeleteAccount _deleteAccount;

  @override
  FutureOr<List<Account>> build() async {
    final repository = ref.watch(accountRepositoryProvider);
    _getAccounts = GetAccounts(repository);
    _addAccount = AddAccount(repository);
    _updateAccount = UpdateAccount(repository);
    _deleteAccount = DeleteAccount(repository);

    return _loadAccounts();
  }

  Future<List<Account>> _loadAccounts() async {
    final result = await _getAccounts.call(null);
    return result.fold(
      (failure) => throw failure,
      (accounts) => accounts,
    );
  }

  // Backwards compatibility / aliases
  Future<void> add(Account account) => addAccount(account);
  Future<void> updateAcc(Account account) => updateAccount(account);
  Future<void> deleteAcc(String id) => archiveAccount(id);

  Future<void> addAccount(Account account) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _addAccount.call(account);
      return result.fold(
        (failure) => throw failure,
        (_) {
          ref.read(autoSyncServiceProvider).scheduleSync();
          return _loadAccounts();
        },
      );
    });
  }

  Future<void> updateAccount(Account account) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _updateAccount.call(account);
      return result.fold(
        (failure) => throw failure,
        (_) {
          ref.read(autoSyncServiceProvider).scheduleSync();
          return _loadAccounts();
        },
      );
    });
  }

  Future<void> archiveAccount(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _deleteAccount.call(id);
      return result.fold(
        (failure) => throw failure,
        (_) {
          ref.read(autoSyncServiceProvider).scheduleSync();
          return _loadAccounts();
        },
      );
    });
  }

  Future<void> setDefault(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final accountsList = await _loadAccounts();
      bool modified = false;
      for (final account in accountsList) {
        final shouldBeDefault = account.id == id;
        if (account.isDefault != shouldBeDefault) {
          final updated = account.copyWith(isDefault: shouldBeDefault);
          final res = await _updateAccount.call(updated);
          res.fold((failure) => throw failure, (_) {
            modified = true;
          });
        }
      }
      if (modified) {
        ref.read(autoSyncServiceProvider).scheduleSync();
      }
      return _loadAccounts();
    });
  }
}

@riverpod
Future<AccountBalance> accountBalance(AccountBalanceRef ref, String accountId) async {
  // Watch transactions to trigger recomputation when they change
  final txsAsync = ref.watch(transactionsNotifierProvider);
  final txs = txsAsync.valueOrNull ?? [];
  
  double totalCredits = 0.0;
  double totalDebits = 0.0;
  
  for (final tx in txs) {
    if (tx.isDeleted || tx.accountId != accountId) continue;
    if (tx.type == TransactionType.credit) {
      totalCredits += tx.amount;
    } else {
      totalDebits += tx.amount;
    }
  }
  
  return AccountBalance(
    totalCredits: totalCredits,
    totalDebits: totalDebits,
    netBalance: totalCredits - totalDebits,
  );
}

@riverpod
Future<double> totalNetWorth(TotalNetWorthRef ref) async {
  final accountsAsync = ref.watch(accountsNotifierProvider);
  final accounts = accountsAsync.valueOrNull ?? [];
  final activeAccounts = accounts.where((a) => !a.isDeleted).toList();
  final activeWallet = ref.watch(activeWalletProvider);
  
  double total = 0.0;
  for (final account in activeAccounts) {
    final balance = await ref.watch(accountBalanceProvider(account.id).future);
    final convertedNet = CurrencyUtils.convert(balance.netBalance, account.currencyCode, activeWallet.currencyCode);
    total += convertedNet;
  }
  return total;
}
