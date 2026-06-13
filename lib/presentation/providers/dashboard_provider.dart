import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tracker_app/domain/entities/monthly_summary.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/presentation/providers/accounts_provider.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';
import 'package:tracker_app/presentation/providers/wallets_provider.dart';
import 'package:tracker_app/core/utils/currency_utils.dart';
import 'package:tracker_app/domain/entities/account.dart';

part 'dashboard_provider.g.dart';

class AccountBalanceInfo {
  final Account account;
  final double balance;
  const AccountBalanceInfo(this.account, this.balance);
}

class DashboardState {
  final MonthlySummary summary;
  final List<Transaction> recentTransactions;
  final DateTime selectedPeriod;
  final double totalNetWorth;
  final List<AccountBalanceInfo> accountBalances;

  const DashboardState({
    required this.summary,
    required this.recentTransactions,
    required this.selectedPeriod,
    required this.totalNetWorth,
    required this.accountBalances,
  });

  DashboardState copyWith({
    MonthlySummary? summary,
    List<Transaction>? recentTransactions,
    DateTime? selectedPeriod,
    double? totalNetWorth,
    List<AccountBalanceInfo>? accountBalances,
  }) {
    return DashboardState(
      summary: summary ?? this.summary,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      totalNetWorth: totalNetWorth ?? this.totalNetWorth,
      accountBalances: accountBalances ?? this.accountBalances,
    );
  }
}

@riverpod
class DashboardNotifier extends _$DashboardNotifier {
  DateTime _selectedPeriod = DateTime.now();

  @override
  FutureOr<DashboardState> build() async {
    // Watch other providers to trigger rebuilds when database changes
    final transactions = ref.watch(transactionsNotifierProvider).valueOrNull ?? [];
    final accounts = ref.watch(accountsNotifierProvider).valueOrNull ?? [];
    final activeWallet = ref.watch(activeWalletProvider);

    // Calculate total net worth dynamically from accounts and transactions
    final activeAccounts = accounts.where((a) => !a.isDeleted).toList();
    double totalNetWorthVal = 0.0;
    final List<AccountBalanceInfo> accountBalances = [];
    
    for (final account in activeAccounts) {
      double accountCredits = 0.0;
      double accountDebits = 0.0;
      for (final tx in transactions) {
        if (tx.isDeleted || tx.accountId != account.id) continue;
        if (tx.type == TransactionType.credit) {
          accountCredits += tx.amount;
        } else {
          accountDebits += tx.amount;
        }
      }
      final accountNet = accountCredits - accountDebits;
      final convertedNet = CurrencyUtils.convert(accountNet, account.currencyCode, activeWallet.currencyCode);
      totalNetWorthVal += convertedNet;
      accountBalances.add(AccountBalanceInfo(account, convertedNet));
    }

    // Now, calculate the Summary for the selected period (_selectedPeriod).
    final startDate = DateTime(_selectedPeriod.year, _selectedPeriod.month, 1);
    final endDate = DateTime(_selectedPeriod.year, _selectedPeriod.month + 1, 1).subtract(const Duration(microseconds: 1));

    double totalCredits = 0.0;
    double totalDebits = 0.0;
    int transactionCount = 0;

    for (final tx in transactions) {
      if (tx.isDeleted) continue;
      // Filter by period
      final txDate = tx.dateTime;
      final isInPeriod = (txDate.isAfter(startDate) || txDate.isAtSameMomentAs(startDate)) &&
                         (txDate.isBefore(endDate) || txDate.isAtSameMomentAs(endDate));
      if (!isInPeriod) continue;

      final convertedAmount = CurrencyUtils.convert(tx.amount, tx.currencyCode, activeWallet.currencyCode);

      if (tx.type == TransactionType.credit) {
        totalCredits += convertedAmount;
      } else {
        totalDebits += convertedAmount;
      }
      transactionCount++;
    }

    final summary = MonthlySummary(
      totalCredits: totalCredits,
      totalDebits: totalDebits,
      netChange: totalCredits - totalDebits,
      transactionCount: transactionCount,
    );

    // Get recent transactions (top 5 sorted by date descending)
    final activeTransactions = transactions.where((tx) => !tx.isDeleted).toList();
    activeTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final recent = activeTransactions.take(5).toList();

    return DashboardState(
      summary: summary,
      recentTransactions: recent,
      selectedPeriod: _selectedPeriod,
      totalNetWorth: totalNetWorthVal,
      accountBalances: accountBalances,
    );
  }

  void changePeriod(DateTime newPeriod) {
    _selectedPeriod = newPeriod;
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    ref.invalidate(transactionsNotifierProvider);
    ref.invalidate(accountsNotifierProvider);
    final _ = await future;
  }
}
