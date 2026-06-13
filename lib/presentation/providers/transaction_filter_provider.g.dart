// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_filter_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$filteredTransactionsHash() =>
    r'4950ee21054326991ab006225b9e4aeac870e273';

/// See also [filteredTransactions].
@ProviderFor(filteredTransactions)
final filteredTransactionsProvider =
    AutoDisposeProvider<List<Transaction>>.internal(
  filteredTransactions,
  name: r'filteredTransactionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$filteredTransactionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef FilteredTransactionsRef = AutoDisposeProviderRef<List<Transaction>>;
String _$transactionFilterNotifierHash() =>
    r'545b3500170ae12d22999b34bedf985fe9d781aa';

/// See also [TransactionFilterNotifier].
@ProviderFor(TransactionFilterNotifier)
final transactionFilterNotifierProvider = AutoDisposeNotifierProvider<
    TransactionFilterNotifier, TransactionFilter>.internal(
  TransactionFilterNotifier.new,
  name: r'transactionFilterNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$transactionFilterNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TransactionFilterNotifier = AutoDisposeNotifier<TransactionFilter>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
