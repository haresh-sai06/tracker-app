import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';

part 'transaction_filter_provider.g.dart';

class TransactionFilter {
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> categoryIds;
  final List<String> accountIds;
  final List<TransactionType> types;
  final double? minAmount;
  final double? maxAmount;
  final List<TransactionSource> sources;

  const TransactionFilter({
    this.searchQuery = '',
    this.startDate,
    this.endDate,
    this.categoryIds = const [],
    this.accountIds = const [],
    this.types = const [],
    this.minAmount,
    this.maxAmount,
    this.sources = const [],
  });

  bool get isActive =>
      searchQuery.isNotEmpty ||
      startDate != null ||
      endDate != null ||
      categoryIds.isNotEmpty ||
      accountIds.isNotEmpty ||
      types.isNotEmpty ||
      minAmount != null ||
      maxAmount != null ||
      sources.isNotEmpty;

  TransactionFilter copyWith({
    String? searchQuery,
    DateTime? Function()? startDate,
    DateTime? Function()? endDate,
    List<String>? categoryIds,
    List<String>? accountIds,
    List<TransactionType>? types,
    double? Function()? minAmount,
    double? Function()? maxAmount,
    List<TransactionSource>? sources,
  }) {
    return TransactionFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      startDate: startDate != null ? startDate() : this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
      categoryIds: categoryIds ?? this.categoryIds,
      accountIds: accountIds ?? this.accountIds,
      types: types ?? this.types,
      minAmount: minAmount != null ? minAmount() : this.minAmount,
      maxAmount: maxAmount != null ? maxAmount() : this.maxAmount,
      sources: sources ?? this.sources,
    );
  }
}

@riverpod
class TransactionFilterNotifier extends _$TransactionFilterNotifier {
  @override
  TransactionFilter build() {
    return const TransactionFilter();
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(
      startDate: () => start,
      endDate: () => end,
    );
  }

  void toggleCategory(String categoryId) {
    final list = List<String>.from(state.categoryIds);
    if (list.contains(categoryId)) {
      list.remove(categoryId);
    } else {
      list.add(categoryId);
    }
    state = state.copyWith(categoryIds: list);
  }

  void toggleAccount(String accountId) {
    final list = List<String>.from(state.accountIds);
    if (list.contains(accountId)) {
      list.remove(accountId);
    } else {
      list.add(accountId);
    }
    state = state.copyWith(accountIds: list);
  }

  void toggleType(TransactionType type) {
    final list = List<TransactionType>.from(state.types);
    if (list.contains(type)) {
      list.remove(type);
    } else {
      list.add(type);
    }
    state = state.copyWith(types: list);
  }

  void toggleSource(TransactionSource source) {
    final list = List<TransactionSource>.from(state.sources);
    if (list.contains(source)) {
      list.remove(source);
    } else {
      list.add(source);
    }
    state = state.copyWith(sources: list);
  }

  void setAmountRange(double? min, double? max) {
    state = state.copyWith(
      minAmount: () => min,
      maxAmount: () => max,
    );
  }

  void clearAll() {
    state = const TransactionFilter();
  }
}

@riverpod
List<Transaction> filteredTransactions(FilteredTransactionsRef ref) {
  final transactionsAsync = ref.watch(transactionsNotifierProvider);
  final filter = ref.watch(transactionFilterNotifierProvider);

  final transactions = transactionsAsync.valueOrNull ?? [];
  
  // Filter out soft-deleted
  var filtered = transactions.where((t) => !t.isDeleted).toList();

  // Search query: case-insensitive match against merchantName or description
  if (filter.searchQuery.trim().isNotEmpty) {
    final query = filter.searchQuery.trim().toLowerCase();
    filtered = filtered.where((t) {
      final merchant = t.merchantName?.toLowerCase() ?? '';
      final desc = t.description.toLowerCase();
      return merchant.contains(query) || desc.contains(query);
    }).toList();
  }

  // Date range
  if (filter.startDate != null) {
    final start = DateTime(filter.startDate!.year, filter.startDate!.month, filter.startDate!.day);
    filtered = filtered.where((t) {
      final tDate = DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day);
      return !tDate.isBefore(start);
    }).toList();
  }
  if (filter.endDate != null) {
    final end = DateTime(filter.endDate!.year, filter.endDate!.month, filter.endDate!.day);
    filtered = filtered.where((t) {
      final tDate = DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day);
      return !tDate.isAfter(end);
    }).toList();
  }

  // Categories
  if (filter.categoryIds.isNotEmpty) {
    filtered = filtered.where((t) => filter.categoryIds.contains(t.category)).toList();
  }

  // Accounts
  if (filter.accountIds.isNotEmpty) {
    filtered = filtered.where((t) => filter.accountIds.contains(t.accountId)).toList();
  }

  // Types
  if (filter.types.isNotEmpty) {
    filtered = filtered.where((t) => filter.types.contains(t.type)).toList();
  }

  // Sources
  if (filter.sources.isNotEmpty) {
    filtered = filtered.where((t) => filter.sources.contains(t.source)).toList();
  }

  // Amount
  if (filter.minAmount != null) {
    filtered = filtered.where((t) => t.amount >= filter.minAmount!).toList();
  }
  if (filter.maxAmount != null) {
    filtered = filtered.where((t) => t.amount <= filter.maxAmount!).toList();
  }

  // Sort by dateTime descending
  filtered.sort((a, b) => b.dateTime.compareTo(a.dateTime));

  return filtered;
}
