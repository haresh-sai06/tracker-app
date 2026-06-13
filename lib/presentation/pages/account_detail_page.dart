import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tracker_app/domain/entities/account.dart';
import 'package:tracker_app/domain/entities/category.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/presentation/providers/accounts_provider.dart';
import 'package:tracker_app/presentation/providers/categories_provider.dart';
import 'package:tracker_app/presentation/providers/settings_provider.dart';
import 'package:tracker_app/presentation/providers/transaction_filter_provider.dart';
import 'package:tracker_app/presentation/providers/wallets_provider.dart';
import 'package:tracker_app/core/utils/currency_utils.dart';

class AccountDetailPage extends ConsumerStatefulWidget {
  final String id;

  const AccountDetailPage({super.key, required this.id});

  @override
  ConsumerState<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends ConsumerState<AccountDetailPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pre-set the filter to this account only
      ref.read(transactionFilterNotifierProvider.notifier).clearAll();
      ref.read(transactionFilterNotifierProvider.notifier).toggleAccount(widget.id);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Revert the filters so they don't leak to other screens
    ref.read(transactionFilterNotifierProvider.notifier).clearAll();
    super.dispose();
  }

  String _getDateGroupKey(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final txDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (txDate == today) {
      return 'Today';
    } else if (txDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsNotifierProvider);
    final categoriesAsync = ref.watch(categoriesNotifierProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);

    final filteredList = ref.watch(filteredTransactionsProvider);
    final filter = ref.watch(transactionFilterNotifierProvider);

    final accounts = accountsAsync.valueOrNull ?? [];
    final categories = categoriesAsync.valueOrNull ?? [];
    final settings = settingsAsync.valueOrNull;

    // Find our current account details or show unknown if not loaded/archived
    final account = accounts.firstWhere(
      (a) => a.id == widget.id,
      orElse: () => Account(
        id: widget.id,
        name: 'Secondary Account',
        type: AccountType.bank,
        isDefault: false,
        isDeleted: false,
      ),
    );

    final activeWallet = ref.watch(activeWalletProvider);
    final currencySymbol = CurrencyUtils.symbolFor(activeWallet.currencyCode);

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/accounts/add', extra: account),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Account Summary Card Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: _AccountSummaryWidget(
                  account: account,
                  currencySymbol: currencySymbol,
                ),
              ),
            ),

            // Search and Filter Header for this Account's transactions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Ledger',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (query) {
                          ref.read(transactionFilterNotifierProvider.notifier).setSearch(query);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search ledger entries...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(transactionFilterNotifierProvider.notifier).setSearch('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Matched Transactions or empty state
            filteredList.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'No Ledger Record',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'No recorded transaction fits your current filters for this account.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildLedgerSliverList(filteredList, categories, currencySymbol),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerSliverList(
    List<Transaction> filteredList,
    List<Category> categories,
    String currencySymbol,
  ) {
    // Group the transactions by date for the sections
    final groupedMap = <String, List<Transaction>>{};
    for (final tx in filteredList) {
      final key = _getDateGroupKey(tx.dateTime);
      if (!groupedMap.containsKey(key)) {
        groupedMap[key] = [];
      }
      groupedMap[key]!.add(tx);
    }

    final listEntries = <dynamic>[];
    groupedMap.forEach((dateHeader, transactions) {
      listEntries.add(dateHeader);
      for (final t in transactions) {
        listEntries.add(t);
      }
    });

    return SliverPadding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 40.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final entry = listEntries[index];

            if (entry is String) {
              return Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 18.0, bottom: 8.0),
                child: Text(
                  entry.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              );
            }

            final tx = entry as Transaction;
            final isDebit = tx.type == TransactionType.debit;

            final category = categories.firstWhere(
              (c) => c.id == tx.category,
              orElse: () => const Category(
                id: 'unknown',
                name: 'Unknown',
                iconCodePoint: 57935,
                colorValue: 0xFF607D8B,
                isDefault: false,
                isDeleted: false,
              ),
            );

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withAlpha(60),
                ),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: ListTile(
                onTap: () => context.push('/transactions/${tx.id}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: Color(category.colorValue).withAlpha(35),
                  radius: 20,
                  child: Icon(
                    IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'),
                    color: Color(category.colorValue),
                    size: 20,
                  ),
                ),
                title: Text(
                  tx.merchantName ?? (tx.description.isNotEmpty ? tx.description : category.name),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _getSourceLabel(tx.source),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.primary.withAlpha(180),
                  ),
                ),
                trailing: Text(
                  '${isDebit ? '-' : '+'}$currencySymbol${tx.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDebit ? Colors.redAccent : Colors.green,
                  ),
                ),
              ),
            );
          },
          childCount: listEntries.length,
        ),
      ),
    );
  }

  String _getSourceLabel(TransactionSource source) {
    switch (source) {
      case TransactionSource.sms:
        return 'SMS';
      case TransactionSource.notification:
        return 'Alert';
      case TransactionSource.email:
        return 'Gmail';
      case TransactionSource.manual:
      default:
        return 'Manual';
    }
  }
}

class _AccountSummaryWidget extends ConsumerWidget {
  final Account account;
  final String currencySymbol;

  const _AccountSummaryWidget({
    required this.account,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(accountBalanceProvider(account.id));
    final activeWallet = ref.watch(activeWalletProvider);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(100),
        ),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getTypeIcon(account.type),
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTypeLabel(account.type).toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (account.bankName != null || account.lastFourDigits != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${account.bankName ?? ""} ${account.lastFourDigits != null ? "•••• " + account.lastFourDigits! : ""}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(180),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),
          
          balanceAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (err, stack) => Text('Error loading balance: $err'),
            data: (balance) {
              final convertedNet = CurrencyUtils.convert(balance.netBalance, account.currencyCode, activeWallet.currencyCode);
              final isNeg = convertedNet < 0;
              return Column(
                children: [
                  Text(
                    'NET BALANCE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(150),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${isNeg ? '-' : ''}$currencySymbol${convertedNet.abs().toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isNeg ? Colors.redAccent : Colors.green[700],
                        ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_upward, size: 14, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  'INCOME',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$currencySymbol${CurrencyUtils.convert(balance.totalCredits, account.currencyCode, activeWallet.currencyCode).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_downward, size: 14, color: Colors.redAccent),
                                SizedBox(width: 4),
                                Text(
                                  'EXPENSES',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$currencySymbol${CurrencyUtils.convert(balance.totalDebits, account.currencyCode, activeWallet.currencyCode).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(AccountType type) {
    switch (type) {
      case AccountType.bank:
        return Icons.account_balance;
      case AccountType.wallet:
        return Icons.account_balance_wallet_outlined;
      case AccountType.cash:
        return Icons.money;
      case AccountType.credit:
        return Icons.credit_card;
    }
  }

  String _getTypeLabel(AccountType type) {
    switch (type) {
      case AccountType.bank:
        return 'Bank Account';
      case AccountType.wallet:
        return 'Digital Wallet';
      case AccountType.cash:
        return 'Cash';
      case AccountType.credit:
        return 'Credit Card';
    }
  }
}
