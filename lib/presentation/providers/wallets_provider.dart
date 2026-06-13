import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_app/domain/entities/currency_wallet.dart';
import 'package:tracker_app/presentation/providers/repository_providers.dart';
import 'package:tracker_app/presentation/providers/accounts_provider.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';
import 'package:tracker_app/presentation/providers/dashboard_provider.dart';
import 'package:tracker_app/presentation/providers/insights_provider.dart';

part 'wallets_provider.g.dart';

final activeWalletProvider = StateProvider<CurrencyWallet>((ref) {
  return CurrencyWallet(
    id: 'INR',
    currencyCode: 'INR',
    label: 'Indian Rupee Wallet',
    isActive: true,
    createdAt: DateTime.now(),
  );
});

@riverpod
class WalletList extends _$WalletList {
  @override
  FutureOr<List<CurrencyWallet>> build() async {
    final repo = ref.watch(currencyWalletRepositoryProvider);
    final result = await repo.getWallets();
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final res = await settingsRepo.getActiveCurrencyCode();
    final activeCode = res.fold((_) => 'INR', (code) => code);

    return result.fold(
      (failure) => [],
      (wallets) {
        if (wallets.isEmpty) {
          // Fallback to INR Wallet if completely empty
          final defaultWallet = CurrencyWallet(
            id: 'INR',
            currencyCode: 'INR',
            label: 'Indian Rupee Wallet',
            isActive: true,
            createdAt: DateTime.now(),
          );
          Future.microtask(() {
            ref.read(activeWalletProvider.notifier).state = defaultWallet;
          });
          return [defaultWallet];
        }

        final active = wallets.firstWhere(
          (w) => w.currencyCode == activeCode,
          orElse: () => wallets.firstWhere(
            (w) => w.isActive,
            orElse: () => wallets.first,
          ),
        );
        Future.microtask(() {
          ref.read(activeWalletProvider.notifier).state = active;
        });
        return wallets;
      },
    );
  }

  Future<void> addWallet(String code, String label) async {
    final normalizedCode = code.toUpperCase().trim();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(currencyWalletRepositoryProvider);
      final newWallet = CurrencyWallet(
        id: normalizedCode,
        currencyCode: normalizedCode,
        label: label,
        isActive: false,
        createdAt: DateTime.now(),
      );
      await repo.addWallet(newWallet);
      
      final result = await repo.getWallets();
      return result.fold(
        (failure) => throw failure,
        (wallets) => wallets,
      );
    });
  }

  Future<void> switchWallet(CurrencyWallet wallet) async {
    final repo = ref.read(currencyWalletRepositoryProvider);
    final walletsResult = await repo.getWallets();
    walletsResult.fold(
      (_) {},
      (wallets) async {
        if (!wallets.any((w) => w.currencyCode == wallet.currencyCode)) {
          await repo.addWallet(wallet);
          // Refresh state so WalletList knows about this new wallet
          final updatedResult = await repo.getWallets();
          updatedResult.fold((_) {}, (updatedWallets) {
            state = AsyncValue.data(updatedWallets);
          });
        }
      },
    );

    final settingsRepo = ref.read(settingsRepositoryProvider);
    await settingsRepo.setActiveCurrencyCode(wallet.currencyCode);
    
    ref.read(activeWalletProvider.notifier).state = wallet;

    // Force reload of other data-dependent providers
    ref.invalidate(transactionsNotifierProvider);
    ref.invalidate(dashboardNotifierProvider);
    ref.invalidate(accountsNotifierProvider);
    ref.invalidate(insightsNotifierProvider);
  }
}
