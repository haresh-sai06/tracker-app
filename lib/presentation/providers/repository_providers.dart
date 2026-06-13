import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tracker_app/domain/repositories/transaction_repository.dart';
import 'package:tracker_app/domain/repositories/category_repository.dart';
import 'package:tracker_app/domain/repositories/account_repository.dart';
import 'package:tracker_app/domain/repositories/settings_repository.dart';
import 'package:tracker_app/domain/repositories/currency_wallet_repository.dart';
import 'package:tracker_app/data/repositories/transaction_repository_impl.dart';
import 'package:tracker_app/data/repositories/category_repository_impl.dart';
import 'package:tracker_app/data/repositories/account_repository_impl.dart';
import 'package:tracker_app/data/repositories/settings_repository_impl.dart';
import 'package:tracker_app/data/repositories/currency_wallet_repository_impl.dart';

part 'repository_providers.g.dart';

@riverpod
TransactionRepository transactionRepository(TransactionRepositoryRef ref) {
  return TransactionRepositoryImpl();
}

@riverpod
CategoryRepository categoryRepository(CategoryRepositoryRef ref) {
  return CategoryRepositoryImpl();
}

@riverpod
AccountRepository accountRepository(AccountRepositoryRef ref) {
  return AccountRepositoryImpl();
}

@riverpod
SettingsRepository settingsRepository(SettingsRepositoryRef ref) {
  return SettingsRepositoryImpl();
}

@riverpod
CurrencyWalletRepository currencyWalletRepository(CurrencyWalletRepositoryRef ref) {
  return CurrencyWalletRepositoryImpl();
}
