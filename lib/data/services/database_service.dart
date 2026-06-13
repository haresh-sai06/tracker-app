import 'package:hive_flutter/hive_flutter.dart';
import 'package:tracker_app/data/models/transaction_model.dart';
import 'package:tracker_app/data/models/category_model.dart';
import 'package:tracker_app/data/models/account_model.dart';
import 'package:tracker_app/data/models/settings_model.dart';
import 'package:tracker_app/data/models/currency_wallet_model.dart';

class DatabaseService {
  static const int currentDbVersion = 2;

  static Box<TransactionModel> get transactionsBox => Hive.box<TransactionModel>('transactions');
  static Box<CategoryModel> get categoriesBox => Hive.box<CategoryModel>('categories');
  static Box<AccountModel> get accountsBox => Hive.box<AccountModel>('accounts');
  static Box get settingsBox => Hive.box('settings');
  static Box<CurrencyWalletModel> get walletsBox => Hive.box<CurrencyWalletModel>('wallets');

  static Future<void> initialize() async {
    await Hive.initFlutter();

    // Register Adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TransactionModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(HiveTransactionTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(HiveTransactionSourceAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(CategoryModelAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(AccountModelAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(HiveAccountTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(SettingsModelAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(CurrencyWalletModelAdapter());
    }

    // Open boxes
    final transactions = await Hive.openBox<TransactionModel>('transactions');
    final categories = await Hive.openBox<CategoryModel>('categories');
    final accounts = await Hive.openBox<AccountModel>('accounts');
    final settings = await Hive.openBox('settings');
    final wallets = await Hive.openBox<CurrencyWalletModel>('wallets');

    // Seed data if first run
    if (settings.get('app_settings') == null) {
      await settings.put('app_settings', SettingsModel(
        isBiometricEnabled: false,
        isSmsParsingEnabled: false,
        isNotificationListenerEnabled: false,
        isGmailSyncEnabled: false,
        defaultAccountId: 'primary_bank',
        defaultCurrencyCode: 'INR',
        themeMode: 'system',
        version: currentDbVersion,
      ));
    }

    if (wallets.isEmpty) {
      final defaultWallet = CurrencyWalletModel(
        id: 'INR',
        currencyCode: 'INR',
        label: 'Indian Rupee Wallet',
        isActive: true,
        createdAt: DateTime.now(),
      );
      await wallets.put(defaultWallet.id, defaultWallet);
    }

    if (categories.isEmpty) {
      final defaultCategories = [
        CategoryModel(id: 'groceries', name: 'Groceries', iconCodePoint: 57943, colorValue: 0xFF4CAF50, isDefault: true, isDeleted: false),
        CategoryModel(id: 'transport', name: 'Transport', iconCodePoint: 57685, colorValue: 0xFF2196F3, isDefault: true, isDeleted: false),
        CategoryModel(id: 'dining', name: 'Dining', iconCodePoint: 57936, colorValue: 0xFFFF9800, isDefault: true, isDeleted: false),
        CategoryModel(id: 'shopping', name: 'Shopping', iconCodePoint: 57951, colorValue: 0xFFE91E63, isDefault: true, isDeleted: false),
        CategoryModel(id: 'bills', name: 'Bills', iconCodePoint: 58872, colorValue: 0xFF9C27B0, isDefault: true, isDeleted: false),
        CategoryModel(id: 'entertainment', name: 'Entertainment', iconCodePoint: 57912, colorValue: 0xFF673AB7, isDefault: true, isDeleted: false),
        CategoryModel(id: 'health', name: 'Health', iconCodePoint: 58711, colorValue: 0xFFF44336, isDefault: true, isDeleted: false),
        CategoryModel(id: 'income', name: 'Income', iconCodePoint: 57895, colorValue: 0xFF009688, isDefault: true, isDeleted: false),
        CategoryModel(id: 'transfer', name: 'Transfer', iconCodePoint: 57683, colorValue: 0xFF795548, isDefault: true, isDeleted: false),
        CategoryModel(id: 'other', name: 'Other', iconCodePoint: 57935, colorValue: 0xFF607D8B, isDefault: true, isDeleted: false),
      ];
      for (final cat in defaultCategories) {
        await categories.put(cat.id, cat);
      }
    }

    if (accounts.isEmpty) {
      final defaultAccount = AccountModel(
        id: 'primary_bank',
        name: 'Primary Account',
        currencyCode: 'INR',
        type: HiveAccountType.bank,
        bankName: 'Main Bank',
        lastFourDigits: '1234',
        isDefault: true,
        isDeleted: false,
      );
      await accounts.put(defaultAccount.id, defaultAccount);
    }

    // Run Migration check
    final schemaVersion = settings.get('schema_version') as int? ?? 1;
    if (schemaVersion < 2) {
      final appSettingsModel = settings.get('app_settings') as SettingsModel?;
      final defaultCurrency = appSettingsModel?.defaultCurrencyCode ?? 'INR';

      final Set<String> foundCurrencies = {};

      // 1. Read all existing transactions
      final allTransactions = transactions.values.toList();
      for (final tx in allTransactions) {
        if (tx.currencyCode == null || tx.currencyCode!.isEmpty) {
          tx.currencyCode = defaultCurrency;
          await tx.save();
        }
        foundCurrencies.add(tx.currencyCode!);
      }

      // 2. Read all existing accounts
      final allAccounts = accounts.values.toList();
      for (final acc in allAccounts) {
        if (acc.currencyCode == null || acc.currencyCode!.isEmpty) {
          acc.currencyCode = defaultCurrency;
          await acc.save();
        }
        foundCurrencies.add(acc.currencyCode!);
      }

      if (foundCurrencies.isEmpty) {
        foundCurrencies.add(defaultCurrency);
      }

      // 3. Create a default CurrencyWallet record for each distinct currencyCode found
      for (final currency in foundCurrencies) {
        if (!wallets.containsKey(currency)) {
          final wallet = CurrencyWalletModel(
            id: currency,
            currencyCode: currency,
            label: '$currency Wallet',
            isActive: currency == defaultCurrency,
            createdAt: DateTime.now(),
          );
          await wallets.put(currency, wallet);
        }
      }

      // 4. Set schema_version = 2
      await settings.put('schema_version', 2);
    }
  }

  static List<String> auditCurrencyConsistency() {
    final inconsistentIds = <String>[];
    assert(() {
      print("[AUDIT] Running currency consistency check...");
      final allTxs = transactionsBox.values.toList();
      int totalCount = 0;
      int failedCount = 0;
      for (final tx in allTxs) {
        totalCount++;
        final cCode = tx.currencyCode;
        if (cCode == null || cCode.isEmpty) {
          failedCount++;
          inconsistentIds.add(tx.id ?? 'Unknown-ID');
          print("[AUDIT ERROR] Transaction ${tx.id} has null or empty currencyCode!");
        }
      }
      print("[AUDIT] Finished. Processed $totalCount transactions. Inconsistent: $failedCount.");
      return true;
    }());
    return inconsistentIds;
  }
}
