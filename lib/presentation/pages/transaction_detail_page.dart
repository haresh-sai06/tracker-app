import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/entities/category.dart';
import 'package:tracker_app/domain/entities/account.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';
import 'package:tracker_app/presentation/providers/categories_provider.dart';
import 'package:tracker_app/presentation/providers/accounts_provider.dart';
import 'package:tracker_app/presentation/providers/settings_provider.dart';
import 'package:tracker_app/presentation/providers/wallets_provider.dart';
import 'package:tracker_app/core/utils/currency_utils.dart';

class TransactionDetailPage extends ConsumerWidget {
  final String id;

  const TransactionDetailPage({
    super.key,
    required this.id,
  });

  Future<void> _showDeleteConfirmation(BuildContext context, WidgetRef ref) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Delete Transaction'),
            ],
          ),
          content: const Text('Are you sure you want to delete this transaction record? This action is reversible if needed but will hide it from active dashboards.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
              onPressed: () async {
                final scaffoldMsg = ScaffoldMessenger.of(context);
                final router = GoRouter.of(context);
                
                // Pop dialog
                Navigator.of(context).pop();
                
                // Soft delete
                await ref.read(transactionsNotifierProvider.notifier).softDelete(id);
                
                scaffoldMsg.showSnackBar(
                  const SnackBar(
                    content: Text('Transaction deleted successfully.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                
                // Pop context back to list
                if (router.canPop()) {
                  router.pop();
                } else {
                  router.go('/transactions');
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsNotifierProvider);
    final categoriesAsync = ref.watch(categoriesNotifierProvider);
    final accountsAsync = ref.watch(accountsNotifierProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        elevation: 0,
        actions: [
          transactionsAsync.when(
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
            data: (transactions) {
              final tx = transactions.firstWhere(
                (t) => t.id == id,
                orElse: () => Transaction(
                  id: '',
                  amount: 0,
                  type: TransactionType.debit,
                  category: '',
                  accountId: '',
                  description: '',
                  source: TransactionSource.manual,
                  dateTime: DateTime.now(),
                  isDeleted: true,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );

              if (tx.id.isEmpty) {
                return const SizedBox();
              }

              return IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  context.push('/transactions/add', extra: tx);
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _showDeleteConfirmation(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading transactions: $err')),
        data: (transactions) {
          final tx = transactions.firstWhere(
            (t) => t.id == id,
            orElse: () => Transaction(
              id: '',
              amount: 0,
              type: TransactionType.debit,
              category: '',
              accountId: '',
              description: '',
              source: TransactionSource.manual,
              dateTime: DateTime.now(),
              isDeleted: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          if (tx.id.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Transaction details not found',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.go('/transactions'),
                    child: const Text('Back to Transactions'),
                  )
                ],
              ),
            );
          }

          // Resolve Category and Account details
          final categories = categoriesAsync.valueOrNull ?? [];
          final accounts = accountsAsync.valueOrNull ?? [];
          final settings = settingsAsync.valueOrNull;

          final category = categories.firstWhere(
            (c) => c.id == tx.category,
            orElse: () => Category(
              id: 'unknown',
              name: 'Unknown Category',
              iconCodePoint: 57935, // Other
              colorValue: 0xFF607D8B,
              isDefault: false,
              isDeleted: false,
            ),
          );

          final account = accounts.firstWhere(
            (a) => a.id == tx.accountId,
            orElse: () => Account(
              id: 'unknown',
              name: 'Unknown Account',
              type: AccountType.bank,
              isDefault: false,
              isDeleted: false,
            ),
          );

          final activeWallet = ref.watch(activeWalletProvider);
          final currencySymbol = CurrencyUtils.symbolFor(activeWallet.currencyCode);
          final convertedAmount = CurrencyUtils.convert(tx.amount, tx.currencyCode, activeWallet.currencyCode);
          final isDebit = tx.type == TransactionType.debit;
          final colorAccent = isDebit ? Colors.redAccent : Colors.green;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Prominent Header Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(80)),
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
                    child: Column(
                      children: [
                        // Category Icon circle
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(category.colorValue).withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'),
                            color: Color(category.colorValue),
                            size: 44,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Amount text
                        Text(
                          '${isDebit ? '- ' : '+ '}$currencySymbol${convertedAmount.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorAccent,
                              ),
                        ),
                        const SizedBox(height: 8),

                        // Merchant or Primary Heading
                        Text(
                          tx.merchantName ?? (tx.description.isNotEmpty ? tx.description : 'Transaction'),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        
                        // Metadata badges row
                        if (tx.merchantName != null && tx.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            tx.description,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Comprehensive Details Grid/List
                Text(
                  'Transaction Details'.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildDetailItem(
                          context,
                          icon: Icons.category,
                          label: 'Category',
                          value: category.name,
                          color: Color(category.colorValue),
                        ),
                        const Divider(height: 24),
                        _buildDetailItem(
                          context,
                          icon: Icons.account_balance,
                          label: 'Account / Wallet',
                          value: account.name,
                          color: Colors.blueAccent,
                        ),
                        const Divider(height: 24),
                        _buildDetailItem(
                          context,
                          icon: Icons.calendar_today,
                          label: 'Date & Time',
                          value: DateFormat('MMM d, yyyy - hh:mm a').format(tx.dateTime),
                        ),
                        const Divider(height: 24),
                        _buildDetailItem(
                          context,
                          icon: Icons.swap_horiz,
                          label: 'Flow Type',
                          value: isDebit ? 'Debit (Expense)' : 'Credit (Income)',
                          color: colorAccent,
                        ),
                        const Divider(height: 24),
                        _buildDetailItem(
                          context,
                          icon: _getSourceIcon(tx.source),
                          label: 'Source',
                          value: _getSourceValue(tx.source),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: color ?? Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(180),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getSourceIcon(TransactionSource source) {
    switch (source) {
      case TransactionSource.sms:
        return Icons.sms_outlined;
      case TransactionSource.notification:
        return Icons.notifications_active_outlined;
      case TransactionSource.email:
        return Icons.email_outlined;
      case TransactionSource.manual:
      default:
        return Icons.edit_note_outlined;
    }
  }

  String _getSourceValue(TransactionSource source) {
    switch (source) {
      case TransactionSource.sms:
        return 'SMS Auto-parsed';
      case TransactionSource.notification:
        return 'Notification Scanned';
      case TransactionSource.email:
        return 'Gmail Sync Engine';
      case TransactionSource.manual:
      default:
        return 'Manual Entry';
    }
  }
}
