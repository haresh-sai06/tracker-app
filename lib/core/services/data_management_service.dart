import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/data/models/transaction_model.dart';
import 'package:tracker_app/core/services/pdf_export_service.dart';
import 'package:tracker_app/data/services/database_service.dart';

class DataManagementService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// closes boxes, deletes files, re-initializes
  static Future<void> clearAllData() async {
    // 1. Close Hive boxes
    await Hive.close();

    // 2. Delete all boxes from disk
    await Hive.deleteFromDisk();

    // 3. Delete Secure Storage
    await _secureStorage.deleteAll();

    // 4. Re-initialize Hive Database
    await DatabaseService.initialize();
  }

  /// calls PdfExportService with all transactions
  static Future<Uint8List> exportAllData() async {
    // 1. Fetch transactions, categories, and settings
    final transactionsBox = DatabaseService.transactionsBox;
    final categoriesBox = DatabaseService.categoriesBox;
    final settingsBox = DatabaseService.settingsBox;

    final allTxsRaw = transactionsBox.values.where((tx) => tx.isDeleted != true).toList();
    
    // Map transactions to entities
    final transactions = allTxsRaw.map((model) {
      return Transaction(
        id: model.id ?? '',
        amount: model.amount ?? 0.0,
        type: model.type == HiveTransactionType.credit ? TransactionType.credit : TransactionType.debit,
        category: model.category ?? '',
        accountId: model.accountId ?? '',
        description: model.description ?? '',
        merchantName: model.merchantName,
        source: model.source == HiveTransactionSource.sms
            ? TransactionSource.sms
            : model.source == HiveTransactionSource.notification
                ? TransactionSource.notification
                : model.source == HiveTransactionSource.email
                    ? TransactionSource.email
                    : TransactionSource.manual,
        rawSourceText: model.rawSourceText,
        dateTime: model.dateTime ?? DateTime.now(),
        isDeleted: model.isDeleted ?? false,
        createdAt: model.createdAt ?? DateTime.now(),
        updatedAt: model.updatedAt ?? DateTime.now(),
      );
    }).toList();

    // Sort transactions by date descending
    transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    // Category mappings ID -> Name
    final Map<String, String> categoryNames = {
      for (final cat in categoriesBox.values) cat.id ?? '': cat.name ?? ''
    };

    // Settings config
    final currentSettings = settingsBox.get('app_settings');
    final currencySymbol = currentSettings?.defaultCurrencyCode == 'EUR' ? '€' : '\$';

    final config = ExportConfig(
      title: 'Complete Financial Journal Archive',
      accountName: 'All Accounts Combined',
      currencySymbol: currencySymbol,
    );

    return await PdfExportService.generatePdf(
      transactions: transactions,
      config: config,
      categoryNames: categoryNames,
    );
  }
}
