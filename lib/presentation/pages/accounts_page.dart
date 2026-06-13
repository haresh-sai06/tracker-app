import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_app/domain/entities/account.dart';
import 'package:tracker_app/domain/entities/account_balance.dart';
import 'package:tracker_app/presentation/providers/accounts_provider.dart';
import 'package:tracker_app/presentation/providers/settings_provider.dart';
import 'package:tracker_app/presentation/providers/wallets_provider.dart';
import 'package:tracker_app/core/utils/currency_utils.dart';

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsNotifierProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final totalNetWorthAsync = ref.watch(totalNetWorthProvider);
    final activeWallet = ref.watch(activeWalletProvider);

    final settings = settingsAsync.valueOrNull;
    final currencySymbol = CurrencyUtils.symbolFor(activeWallet.currencyCode);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
        onPressed: () => context.push('/accounts/add'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              shadowColor: Colors.transparent,
              backgroundColor: Theme.of(context).colorScheme.background,
              title: Text(
                'Accounts',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
              ),
              actions: [
                // Filter chip/icon to toggle archived accounts
                IconButton(
                  tooltip: _showArchived ? 'Show Active' : 'Show Archived',
                  icon: Icon(
                    _showArchived ? Icons.visibility : Icons.visibility_off,
                    color: _showArchived ? Theme.of(context).colorScheme.primary : null,
                  ),
                  onPressed: () {
                    setState(() {
                      _showArchived = !_showArchived;
                    });
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            
            // Net Worth Card Header (only show active accounts' worth)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: totalNetWorthAsync.when(
                  loading: () => const _NetWorthShimmer(),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                  data: (worth) => _NetWorthCard(worth: worth, currencySymbol: currencySymbol),
                ),
              ),
            ),

            // Toggle Bar / Chip Row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _showArchived ? 'Archived Accounts' : 'Active Accounts',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    FilterChip(
                      selected: _showArchived,
                      label: const Text('Archived'),
                      onSelected: (val) {
                        setState(() {
                          _showArchived = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Accounts List
            accountsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => SliverFillRemaining(
                child: Center(child: Text('Error loading accounts: $err')),
              ),
              data: (accounts) {
                final list = accounts.where((a) => a.isDeleted == _showArchived).toList();

                if (list.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _showArchived ? Icons.archive_outlined : Icons.account_balance_wallet_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _showArchived ? 'No Archived Accounts' : 'No Active Accounts',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _showArchived
                                ? 'Your archived accounts will appear here.'
                                : 'Create an account to begin tracking. Tap the FAB of this screen to create your first Account.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 90.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final account = list[index];
                        return AccountCard(
                          account: account,
                          currencySymbol: currencySymbol,
                          onTap: () => context.push('/accounts/${account.id}'),
                          onLongPress: () => _showAccountOperations(context, account),
                        );
                      },
                      childCount: list.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountOperations(BuildContext context, Account account) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  account.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const Divider(height: 1),
              
              // Set Default option (only show if it is not already default and not archived)
              if (!account.isDefault && !account.isDeleted)
                ListTile(
                  leading: const Icon(Icons.star_outline, color: Colors.amber),
                  title: const Text('Set as Default'),
                  onTap: () {
                    ref.read(accountsNotifierProvider.notifier).setDefault(account.id);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${account.name} is now your default account.')),
                    );
                  },
                ),
                
              // Edit option
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Account Info'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/accounts/add', extra: account);
                },
              ),
              
              // Archive / Unarchive option
              ListTile(
                leading: Icon(
                  account.isDeleted ? Icons.unarchive_outlined : Icons.archive_outlined,
                  color: account.isDeleted ? Colors.green : Colors.redAccent,
                ),
                title: Text(account.isDeleted ? 'Restore / Unarchive' : 'Archive Account'),
                onTap: () async {
                  final notifier = ref.read(accountsNotifierProvider.notifier);
                  if (account.isDeleted) {
                    await notifier.updateAccount(account.copyWith(isDeleted: false));
                  } else {
                    await notifier.archiveAccount(account.id);
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(account.isDeleted
                            ? 'Account restored successfully'
                            : 'Account archived successfully'),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class AccountCard extends ConsumerWidget {
  final Account account;
  final String currencySymbol;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const AccountCard({
    super.key,
    required this.account,
    required this.currencySymbol,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(accountBalanceProvider(account.id));
    final activeWallet = ref.watch(activeWalletProvider);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(60),
          width: 1,
        ),
      ),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              // Icon Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getTypeIcon(account.type),
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // Text Information Area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            account.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            account.currencyCode.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        if (account.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha(35),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 10, color: Colors.amber),
                                SizedBox(width: 2),
                                Text(
                                  'Default',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Bank Name, optionally last 4 digits
                    Row(
                      children: [
                        if (account.bankName != null) ...[
                          Text(
                            account.bankName!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(180),
                                ),
                          ),
                          if (account.lastFourDigits != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '•',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ],
                        if (account.lastFourDigits != null)
                          Text(
                            '•••• ${account.lastFourDigits}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(180),
                                  fontFamily: 'monospace',
                                ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Computed Balance Area
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  balanceAsync.when(
                    loading: () => const Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
                    error: (err, stack) => const Text('error', style: TextStyle(color: Colors.red)),
                    data: (balance) {
                      final convertedNet = CurrencyUtils.convert(balance.netBalance, account.currencyCode, activeWallet.currencyCode);
                      final isNeg = convertedNet < 0;
                      return Text(
                        '${isNeg ? '-' : ''}$currencySymbol${convertedNet.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isNeg ? Colors.redAccent : Colors.green[700],
                          letterSpacing: -0.2,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.arrow_upward, size: 12, color: Colors.green),
                      balanceAsync.when(
                        loading: () => const Text('', style: TextStyle(fontSize: 10)),
                        error: (_, __) => const Text(''),
                        data: (b) {
                          final convertedCredits = CurrencyUtils.convert(b.totalCredits, account.currencyCode, activeWallet.currencyCode);
                          return Text(' $currencySymbol${convertedCredits.round()}', style: const TextStyle(fontSize: 10, color: Colors.grey));
                        },
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_downward, size: 12, color: Colors.redAccent),
                      balanceAsync.when(
                        loading: () => const Text('', style: TextStyle(fontSize: 10)),
                        error: (_, __) => const Text(''),
                        data: (b) {
                          final convertedDebits = CurrencyUtils.convert(b.totalDebits, account.currencyCode, activeWallet.currencyCode);
                          return Text(' $currencySymbol${convertedDebits.round()}', style: const TextStyle(fontSize: 10, color: Colors.grey));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
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
}

class _NetWorthCard extends StatelessWidget {
  final double worth;
  final String currencySymbol;

  const _NetWorthCard({required this.worth, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final isNeg = worth < 0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primaryContainer.withAlpha(160),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withAlpha(40),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL NET WORTH',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary.withAlpha(180),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '${isNeg ? '-' : ''}$currencySymbol${worth.abs().toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Aggregated net balance of active accounts',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary.withAlpha(200),
                ),
          ),
        ],
      ),
    );
  }
}

class _NetWorthShimmer extends StatelessWidget {
  const _NetWorthShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
