// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accounts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$accountBalanceHash() => r'1ceb2d6bf8eac76d5b7262bf0c3bdb3416b0b650';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [accountBalance].
@ProviderFor(accountBalance)
const accountBalanceProvider = AccountBalanceFamily();

/// See also [accountBalance].
class AccountBalanceFamily extends Family<AsyncValue<AccountBalance>> {
  /// See also [accountBalance].
  const AccountBalanceFamily();

  /// See also [accountBalance].
  AccountBalanceProvider call(
    String accountId,
  ) {
    return AccountBalanceProvider(
      accountId,
    );
  }

  @override
  AccountBalanceProvider getProviderOverride(
    covariant AccountBalanceProvider provider,
  ) {
    return call(
      provider.accountId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'accountBalanceProvider';
}

/// See also [accountBalance].
class AccountBalanceProvider extends AutoDisposeFutureProvider<AccountBalance> {
  /// See also [accountBalance].
  AccountBalanceProvider(
    String accountId,
  ) : this._internal(
          (ref) => accountBalance(
            ref as AccountBalanceRef,
            accountId,
          ),
          from: accountBalanceProvider,
          name: r'accountBalanceProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$accountBalanceHash,
          dependencies: AccountBalanceFamily._dependencies,
          allTransitiveDependencies:
              AccountBalanceFamily._allTransitiveDependencies,
          accountId: accountId,
        );

  AccountBalanceProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.accountId,
  }) : super.internal();

  final String accountId;

  @override
  Override overrideWith(
    FutureOr<AccountBalance> Function(AccountBalanceRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AccountBalanceProvider._internal(
        (ref) => create(ref as AccountBalanceRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        accountId: accountId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<AccountBalance> createElement() {
    return _AccountBalanceProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AccountBalanceProvider && other.accountId == accountId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, accountId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin AccountBalanceRef on AutoDisposeFutureProviderRef<AccountBalance> {
  /// The parameter `accountId` of this provider.
  String get accountId;
}

class _AccountBalanceProviderElement
    extends AutoDisposeFutureProviderElement<AccountBalance>
    with AccountBalanceRef {
  _AccountBalanceProviderElement(super.provider);

  @override
  String get accountId => (origin as AccountBalanceProvider).accountId;
}

String _$totalNetWorthHash() => r'94e5bf5d585d86d70b404af0427d5d31ac268e09';

/// See also [totalNetWorth].
@ProviderFor(totalNetWorth)
final totalNetWorthProvider = AutoDisposeFutureProvider<double>.internal(
  totalNetWorth,
  name: r'totalNetWorthProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$totalNetWorthHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef TotalNetWorthRef = AutoDisposeFutureProviderRef<double>;
String _$accountsNotifierHash() => r'0a46a2ac9ac14813b422bae2157e99712cac4423';

/// See also [AccountsNotifier].
@ProviderFor(AccountsNotifier)
final accountsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<AccountsNotifier, List<Account>>.internal(
  AccountsNotifier.new,
  name: r'accountsNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$accountsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AccountsNotifier = AutoDisposeAsyncNotifier<List<Account>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
