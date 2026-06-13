import 'dart:async';
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
import 'package:tracker_app/presentation/providers/transaction_filter_provider.dart';
import 'package:tracker_app/presentation/providers/wallets_provider.dart';
import 'package:tracker_app/core/utils/currency_utils.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Synchronize initial search controller text if a filter already exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentFilter = ref.read(transactionFilterNotifierProvider);
      if (currentFilter.searchQuery.isNotEmpty) {
        _searchController.text = currentFilter.searchQuery;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(transactionFilterNotifierProvider.notifier).setSearch(query);
    });
  }

  int _getActiveFilterCount(TransactionFilter filter) {
    int count = 0;
    if (filter.startDate != null || filter.endDate != null) count++;
    if (filter.categoryIds.isNotEmpty) count += filter.categoryIds.length;
    if (filter.accountIds.isNotEmpty) count += filter.accountIds.length;
    if (filter.types.isNotEmpty) count += filter.types.length;
    if (filter.sources.isNotEmpty) count += filter.sources.length;
    if (filter.minAmount != null || filter.maxAmount != null) count++;
    return count;
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

  void _showFilterBottomSheet(BuildContext context, TransactionFilter currentFilter) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return FilterBottomSheetContent(initialFilter: currentFilter);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsNotifierProvider);
    final categoriesAsync = ref.watch(categoriesNotifierProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);

    final filteredList = ref.watch(filteredTransactionsProvider);
    final filter = ref.watch(transactionFilterNotifierProvider);

    final categories = categoriesAsync.valueOrNull ?? [];
    final settings = settingsAsync.valueOrNull;
    final activeWallet = ref.watch(activeWalletProvider);
    final currencySymbol = CurrencyUtils.symbolFor(activeWallet.currencyCode);

    // To check if DB has *any* active non-deleted transactions at all
    final allTransactions = transactionsAsync.valueOrNull ?? [];
    final totalActiveCount = allTransactions.where((t) => !t.isDeleted).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
        onPressed: () => context.push('/transactions/add'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Floating & Snapping SliverAppBar with Search Bar & Filter action
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: false,
              elevation: 0,
              backgroundColor: Theme.of(context).colorScheme.background,
              title: Text(
                'Transactions',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
              ),
              actions: [
                IconButton(
                  onPressed: () => _showFilterBottomSheet(context, filter),
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.tune_outlined, size: 26),
                      if (filter.isActive)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              _getActiveFilterCount(filter).toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(68.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search merchant or description...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(transactionFilterNotifierProvider.notifier).setSearch('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Horizontal Active Filters Row (Sliver)
            if (filter.isActive)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ActiveFiltersRow(filter: filter),
                ),
              ),

            // Main body content
            transactionsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => SliverFillRemaining(
                child: Center(child: Text('Error loading records: $err')),
              ),
              data: (_) {
                // If there are literally no transactions at all in the DB
                if (totalActiveCount == 0) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withAlpha(40),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.auto_awesome_motion,
                              size: 64,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No Transactions Yet',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Keep track of manual payments or let device sensors securely capture bank receipts via SMS.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => context.push('/transactions/add'),
                            icon: const Icon(Icons.add),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            label: const Text('Add your first entry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // If filters are active but nothing matches
                if (filteredList.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off_outlined, size: 60, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No Matching Transactions',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try adjusting or clearing your search options and filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              ref.read(transactionFilterNotifierProvider.notifier).clearAll();
                            },
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Reset All Filters'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Group the matched transactions by Date for the beautiful Visual sections
                final groupedMap = <String, List<Transaction>>{};
                for (final tx in filteredList) {
                  final key = _getDateGroupKey(tx.dateTime);
                  if (!groupedMap.containsKey(key)) {
                    groupedMap[key] = [];
                  }
                  groupedMap[key]!.add(tx);
                }

                // Flatten the lists into list entries
                final listEntries = <dynamic>[];
                groupedMap.forEach((dateHeader, transactions) {
                  listEntries.add(dateHeader);
                  for (final t in transactions) {
                    listEntries.add(t);
                  }
                });

                return SliverPadding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 90.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final entry = listEntries[index];

                        if (entry is String) {
                          // Render beautiful visual date group header
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

                        // Render Dismissible transaction item
                        final tx = entry as Transaction;
                        final isDebit = tx.type == TransactionType.debit;

                        final category = categories.firstWhere(
                          (c) => c.id == tx.category,
                          orElse: () => const Category(
                            id: 'unknown',
                            name: 'Unknown',
                            iconCodePoint: 57935, // fallback "Other"
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
                              width: 1,
                            ),
                          ),
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          clipBehavior: Clip.antiAlias,
                          child: Dismissible(
                            key: Key(tx.id),
                            background: Container(
                              color: Colors.redAccent,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20.0),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.delete_sweep_outlined, color: Colors.white),
                                ],
                              ),
                            ),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) async {
                              final originalTx = tx;
                              await ref.read(transactionsNotifierProvider.notifier).softDelete(tx.id);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Transaction record deleted.'),
                                    action: SnackBarAction(
                                      label: 'UNDO',
                                      textColor: Colors.yellow,
                                      onPressed: () async {
                                        // restore transaction
                                        await ref
                                            .read(transactionsNotifierProvider.notifier)
                                            .updateTx(originalTx.copyWith(isDeleted: false));
                                      },
                                    ),
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            },
                            child: ListTile(
                              onTap: () => context.push('/transactions/${tx.id}'),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: Color(category.colorValue).withAlpha(35),
                                radius: 24,
                                child: Icon(
                                  IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'),
                                  color: Color(category.colorValue),
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                tx.merchantName ?? (tx.description.isNotEmpty ? tx.description : category.name),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  if (tx.merchantName != null && tx.description.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2.0),
                                      child: Text(
                                        tx.description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(180),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Text(
                                        _getSourceLabel(tx.source),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary.withAlpha(180),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        DateFormat('hh:mm a').format(tx.dateTime),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(140),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isDebit ? '-' : '+'}$currencySymbol${CurrencyUtils.convert(tx.amount, tx.currencyCode, activeWallet.currencyCode).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: isDebit ? Colors.redAccent : Colors.green,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  if (tx.source != TransactionSource.manual) ...[
                                    const SizedBox(height: 4),
                                    Icon(
                                      _getSourceIcon(tx.source),
                                      size: 14,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: listEntries.length,
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
}

// Visual horizontal Active Filter Chips Row under the header
class ActiveFiltersRow extends ConsumerWidget {
  final TransactionFilter filter;

  const ActiveFiltersRow({
    super.key,
    required this.filter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesNotifierProvider).valueOrNull ?? [];
    final accounts = ref.watch(accountsNotifierProvider).valueOrNull ?? [];
    final settings = ref.watch(settingsNotifierProvider).valueOrNull;
    final activeWallet = ref.watch(activeWalletProvider);
    final currencySymbol = CurrencyUtils.symbolFor(activeWallet.currencyCode);

    final notifier = ref.read(transactionFilterNotifierProvider.notifier);
    final chips = <Widget>[];

    // Search chip
    if (filter.searchQuery.isNotEmpty) {
      chips.add(
        _buildFilterChip(
          context,
          label: 'Search: "${filter.searchQuery}"',
          onDeleted: () => notifier.setSearch(''),
        ),
      );
    }

    // Date chip
    if (filter.startDate != null || filter.endDate != null) {
      String label = 'Date';
      if (filter.startDate != null && filter.endDate != null) {
        if (filter.startDate == filter.endDate) {
          label = DateFormat('MMM d').format(filter.startDate!);
        } else {
          label = '${DateFormat('MMM d').format(filter.startDate!)} - ${DateFormat('MMM d').format(filter.endDate!)}';
        }
      } else if (filter.startDate != null) {
        label = '>= ${DateFormat('MMM d').format(filter.startDate!)}';
      } else if (filter.endDate != null) {
        label = '<= ${DateFormat('MMM d').format(filter.endDate!)}';
      }

      chips.add(
        _buildFilterChip(
          context,
          label: label,
          onDeleted: () => notifier.setDateRange(null, null),
        ),
      );
    }

    // Category chips
    for (final catId in filter.categoryIds) {
      final cat = categories.firstWhere((c) => c.id == catId, orElse: () => Category(id: catId, name: catId, colorValue: 0, iconCodePoint: 0, isDefault: false, isDeleted: false));
      chips.add(
        _buildFilterChip(
          context,
          label: 'Cat: ${cat.name}',
          avatar: Icon(IconData(cat.iconCodePoint, fontFamily: 'MaterialIcons'), size: 14, color: Color(cat.colorValue)),
          onDeleted: () => notifier.toggleCategory(catId),
        ),
      );
    }

    // Account chips
    for (final actId in filter.accountIds) {
      final act = accounts.firstWhere((a) => a.id == actId, orElse: () => Account(id: actId, name: actId, type: AccountType.bank, isDefault: false, isDeleted: false));
      chips.add(
        _buildFilterChip(
          context,
          label: 'Acc: ${act.name}',
          onDeleted: () => notifier.toggleAccount(actId),
        ),
      );
    }

    // Type chips
    for (final type in filter.types) {
      final label = type == TransactionType.credit ? 'Type: Credit' : 'Type: Debit';
      chips.add(
        _buildFilterChip(
          context,
          label: label,
          onDeleted: () => notifier.toggleType(type),
        ),
      );
    }

    // Source chips
    for (final src in filter.sources) {
      chips.add(
        _buildFilterChip(
          context,
          label: 'Source: ${src.name}',
          onDeleted: () => notifier.toggleSource(src),
        ),
      );
    }

    // Amount range chip
    if (filter.minAmount != null || filter.maxAmount != null) {
      String label = 'Amount: ';
      if (filter.minAmount != null && filter.maxAmount != null) {
        label += '$currencySymbol${filter.minAmount!.round()} - $currencySymbol${filter.maxAmount!.round()}';
      } else if (filter.minAmount != null) {
        label += '>= $currencySymbol${filter.minAmount!.round()}';
      } else if (filter.maxAmount != null) {
        label += '<= $currencySymbol${filter.maxAmount!.round()}';
      }

      chips.add(
        _buildFilterChip(
          context,
          label: label,
          onDeleted: () => notifier.setAmountRange(null, null),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox();

    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            scrollDirection: Axis.horizontal,
            itemCount: chips.length,
            separatorBuilder: (context, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) => chips[idx],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required VoidCallback onDeleted,
    Widget? avatar,
  }) {
    return InputChip(
      avatar: avatar,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      shadowColor: Colors.transparent,
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: onDeleted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.primary.withAlpha(50)),
      ),
    );
  }
}

// Stateful bottom sheet content inside modal
class FilterBottomSheetContent extends ConsumerStatefulWidget {
  final TransactionFilter initialFilter;

  const FilterBottomSheetContent({
    super.key,
    required this.initialFilter,
  });

  @override
  ConsumerState<FilterBottomSheetContent> createState() => _FilterBottomSheetContentState();
}

class _FilterBottomSheetContentState extends ConsumerState<FilterBottomSheetContent> {
  DateTime? _startDate;
  DateTime? _endDate;
  final List<String> _categoryIds = [];
  final List<String> _accountIds = [];
  final List<TransactionType> _types = [];
  final List<TransactionSource> _sources = [];
  double? _minAmount;
  double? _maxAmount;

  RangeValues _amountRange = const RangeValues(0, 10000);
  String _selectedPreset = '';

  @override
  void initState() {
    super.initState();
    final filter = widget.initialFilter;
    _startDate = filter.startDate;
    _endDate = filter.endDate;
    _categoryIds.addAll(filter.categoryIds);
    _accountIds.addAll(filter.accountIds);
    _types.addAll(filter.types);
    _sources.addAll(filter.sources);
    _minAmount = filter.minAmount;
    _maxAmount = filter.maxAmount;

    _amountRange = RangeValues(
      _minAmount ?? 0,
      _maxAmount ?? 10000,
    );

    // Recognize presets from loaded dates
    if (_startDate != null && _endDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (_startDate == today && _endDate == today) {
        _selectedPreset = 'today';
      } else if (_startDate == today.subtract(Duration(days: now.weekday - 1)) && _endDate == today) {
        _selectedPreset = 'week';
      } else if (_startDate == DateTime(now.year, now.month, 1) && _endDate == today) {
        _selectedPreset = 'month';
      } else {
        _selectedPreset = 'custom';
      }
    }
  }

  void _selectPreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _selectedPreset = preset;
      if (preset == 'today') {
        _startDate = today;
        _endDate = today;
      } else if (preset == 'week') {
        final weekday = now.weekday;
        _startDate = today.subtract(Duration(days: weekday - 1));
        _endDate = today;
      } else if (preset == 'month') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = today;
      } else if (preset == 'custom') {
        _showCustomDateRangePicker();
      }
    });
  }

  Future<void> _showCustomDateRangePicker() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
        _selectedPreset = 'custom';
      });
    }
  }

  void _applyFilters() {
    ref.read(transactionFilterNotifierProvider.notifier).state = TransactionFilter(
      searchQuery: widget.initialFilter.searchQuery, // keep search query intact
      startDate: _startDate,
      endDate: _endDate,
      categoryIds: _categoryIds,
      accountIds: _accountIds,
      types: _types,
      minAmount: _minAmount,
      maxAmount: _maxAmount,
      sources: _sources,
    );
    Navigator.of(context).pop();
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _categoryIds.clear();
      _accountIds.clear();
      _types.clear();
      _sources.clear();
      _minAmount = null;
      _maxAmount = null;
      _amountRange = const RangeValues(0, 10000);
      _selectedPreset = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesNotifierProvider).valueOrNull ?? [];
    final accounts = ref.watch(accountsNotifierProvider).valueOrNull ?? [];
    final settings = ref.watch(settingsNotifierProvider).valueOrNull;
    final activeWallet = ref.watch(activeWalletProvider);
    final currencySymbol = CurrencyUtils.symbolFor(activeWallet.currencyCode);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header bar
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Records',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable fields
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                children: [
                  // --- Date Range preset chips ---
                  Text(
                    'Date Window',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildPresetChip('Today', 'today'),
                      const SizedBox(width: 8),
                      _buildPresetChip('This Week', 'week'),
                      const SizedBox(width: 8),
                      _buildPresetChip('This Month', 'month'),
                      const SizedBox(width: 8),
                      _buildPresetChip('Custom...', 'custom'),
                    ],
                  ),
                  if (_startDate != null && _endDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                      child: Text(
                        'Selected: ${DateFormat('MMMM d, yyyy').format(_startDate!)} - ${DateFormat('MMMM d, yyyy').format(_endDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // --- Types Selection ---
                  Text(
                    'Flow Type',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildTypeToggle(),
                  const SizedBox(height: 24),

                  // --- Category selector ---
                  Text(
                    'Categories',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(50)),
                    ),
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: categories.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: Text('No categories available.')),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: categories.length,
                            separatorBuilder: (context, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final isSelected = _categoryIds.contains(cat.id);
                              return CheckboxListTile(
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                value: isSelected,
                                title: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Color(cat.colorValue).withAlpha(40),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        IconData(cat.iconCodePoint, fontFamily: 'MaterialIcons'),
                                        color: Color(cat.colorValue),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(cat.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _categoryIds.add(cat.id);
                                    } else {
                                      _categoryIds.remove(cat.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),

                  // --- Account Multi-Select ---
                  Text(
                    'Accounts',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(50)),
                    ),
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: accounts.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: Text('No accounts available.')),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: accounts.length,
                            separatorBuilder: (context, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final act = accounts[index];
                              final isSelected = _accountIds.contains(act.id);
                              return CheckboxListTile(
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                value: isSelected,
                                title: Row(
                                  children: [
                                    const Icon(Icons.account_balance, size: 18, color: Colors.blueAccent),
                                    const SizedBox(width: 12),
                                    Text(act.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _accountIds.add(act.id);
                                    } else {
                                      _accountIds.remove(act.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),

                  // --- Amount limits Slider ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount Range',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$currencySymbol${_amountRange.start.round()} - $currencySymbol${_amountRange.end.round()}+',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RangeSlider(
                    values: _amountRange,
                    min: 0,
                    max: 10000,
                    divisions: 100,
                    activeColor: Theme.of(context).colorScheme.primary,
                    labels: RangeLabels(
                      '$currencySymbol${_amountRange.start.round()}',
                      '$currencySymbol${_amountRange.end.round()}',
                    ),
                    onChanged: (RangeValues val) {
                      setState(() {
                        _amountRange = val;
                        _minAmount = val.start == 0 ? null : val.start;
                        _maxAmount = val.end == 10000 ? null : val.end;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${currencySymbol}0', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      Text('${currencySymbol}10,000+', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),

            // Action apply buttons fixed bottom
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPresetChip(String label, String value) {
    final isSelected = _selectedPreset == value;
    return Expanded(
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: isSelected,
        onSelected: (_) => _selectPreset(value),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildTypeOption('All', []),
          _buildTypeOption('Credit', [TransactionType.credit]),
          _buildTypeOption('Debit', [TransactionType.debit]),
        ],
      ),
    );
  }

  Widget _buildTypeOption(String label, List<TransactionType> matchTypes) {
    final isSelected = (matchTypes.isEmpty && _types.isEmpty) ||
        (matchTypes.isNotEmpty && _types.length == matchTypes.length && _types.first == matchTypes.first);

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _types.clear();
            _types.addAll(matchTypes);
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
