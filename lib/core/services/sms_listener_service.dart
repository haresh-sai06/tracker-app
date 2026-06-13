import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_app/core/services/sms_parser_service.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/entities/category.dart';
import 'package:tracker_app/presentation/providers/accounts_provider.dart';
import 'package:tracker_app/presentation/providers/categories_provider.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';
import 'package:tracker_app/presentation/providers/settings_provider.dart';

final smsListenerServiceProvider = Provider<SmsListenerService>((ref) {
  return SmsListenerService(ref);
});

class SmsListenerService {
  final Ref _ref;
  static const _channel = MethodChannel('com.yourapp.tracker/sms');
  bool _isInitialized = false;

  SmsListenerService(this._ref);

  void initialize(BuildContext context) {
    if (_isInitialized) return;
    _isInitialized = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onSmsReceived':
          final map = call.arguments as Map?;
          if (map != null) {
            final sender = map['sender'] as String? ?? 'Unknown';
            final body = map['body'] as String? ?? '';
            _handleIncomingSms(context, sender, body);
          }
          break;
      }
    });

    // Check for any pending SMS that launched the app from a notification tap
    _checkPendingSms(context);
  }

  Future<void> _checkPendingSms(BuildContext context) async {
    try {
      final map = await _channel.invokeMethod('getPendingSms') as Map?;
      if (map != null) {
        final sender = map['sender'] as String? ?? 'Unknown';
        final body = map['body'] as String? ?? '';
        _processSmsAndOpenReview(context, sender, body);
      }
    } catch (e) {
      debugPrint('Error getting pending SMS: $e');
    }
  }

  Future<void> _handleIncomingSms(BuildContext context, String sender, String body) async {
    debugPrint('[SmsListener] Received event from $sender - Body: "$body"');
    final settings = _ref.read(settingsNotifierProvider).valueOrNull;
    if (settings == null) {
      debugPrint('[SmsListener] Settings is null, ignoring.');
      return;
    }
    if (!settings.isSmsParsingEnabled) {
      debugPrint('[SmsListener] SMS parsing is disabled in settings, ignoring.');
      return;
    }

    // Parse the SMS
    final parsedTx = await SmsParserService.parseSms(body);
    if (parsedTx == null) {
      debugPrint('[SmsListener] Failed to parse transaction from SMS body: "$body"');
      return;
    }

    debugPrint('[SmsListener] Parsed transaction successfully! Amount: ${parsedTx.amount}, Merchant: ${parsedTx.merchantName}');

    // Trigger a native notification so user can tap to review/view details later
    try {
      await _channel.invokeMethod('showTestSmsNotification', {
        'sender': sender,
        'body': body,
      });
    } catch (e) {
      debugPrint('Failed to show native notification: $e');
    }

    // Auto-insert transaction directly into database
    final accountsAsync = _ref.read(accountsNotifierProvider);
    final categoriesAsync = _ref.read(categoriesNotifierProvider);
    final accounts = accountsAsync.valueOrNull ?? [];
    final categories = categoriesAsync.valueOrNull ?? [];

    if (accounts.isEmpty) {
      debugPrint('[SmsListener] Accounts list is empty! Cannot save transaction.');
      return;
    }

    if (accounts.isNotEmpty) {
        final matchedAccount = accounts.firstWhere(
          (a) => parsedTx.accountLastFour != null && a.lastFourDigits != null && a.lastFourDigits!.contains(parsedTx.accountLastFour!),
          orElse: () => accounts.first,
        );
        final nameLower = parsedTx.merchantName.toLowerCase();
        Category? matchedCategory;
        for (final c in categories) {
          if (nameLower.contains(c.name.toLowerCase())) {
            matchedCategory = c;
            break;
          }
        }
        
        final accountId = matchedAccount.id;
        final categoryId = matchedCategory?.id ?? (categories.isNotEmpty ? categories.first.id : 'groceries');

        // Generate deterministic ID
        final bytes = utf8.encode('$sender:$body');
        final txId = sha256.convert(bytes).toString();

        final now = DateTime.now();
        final newTx = Transaction(
          id: txId,
          amount: parsedTx.amount,
          type: parsedTx.type,
          category: categoryId,
          accountId: accountId,
          description: 'Auto-Imported: ${parsedTx.merchantName}',
          merchantName: parsedTx.merchantName,
          source: TransactionSource.sms,
          rawSourceText: body,
          dateTime: now,
          isDeleted: false,
          createdAt: now,
          updatedAt: now,
        );

        try {
          await _ref.read(transactionsNotifierProvider.notifier).add(newTx);
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Auto-imported transaction of Rs. ${parsedTx.amount.toStringAsFixed(2)} at ${parsedTx.merchantName}!'),
                duration: const Duration(seconds: 12),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                action: SnackBarAction(
                  label: 'EDIT',
                  textColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  onPressed: () {
                    context.push('/transactions/$txId');
                  },
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('Failed to auto-save transaction: $e');
        }
      }
  }

  Future<void> _processSmsAndOpenReview(BuildContext context, String sender, String body) async {
    final parsedTx = await SmsParserService.parseSms(body);
    if (parsedTx != null) {
      final accountsAsync = _ref.read(accountsNotifierProvider);
      final categoriesAsync = _ref.read(categoriesNotifierProvider);
      final accounts = accountsAsync.valueOrNull ?? [];
      final categories = categoriesAsync.valueOrNull ?? [];

      if (accounts.isNotEmpty) {
        final matchedAccount = accounts.firstWhere(
          (a) => parsedTx.accountLastFour != null && a.lastFourDigits != null && a.lastFourDigits!.contains(parsedTx.accountLastFour!),
          orElse: () => accounts.first,
        );
        final nameLower = parsedTx.merchantName.toLowerCase();
        Category? matchedCategory;
        for (final c in categories) {
          if (nameLower.contains(c.name.toLowerCase())) {
            matchedCategory = c;
            break;
          }
        }
        
        final accountId = matchedAccount.id;
        final categoryId = matchedCategory?.id ?? (categories.isNotEmpty ? categories.first.id : 'groceries');

        final bytes = utf8.encode('$sender:$body');
        final txId = sha256.convert(bytes).toString();

        final now = DateTime.now();
        final newTx = Transaction(
          id: txId,
          amount: parsedTx.amount,
          type: parsedTx.type,
          category: categoryId,
          accountId: accountId,
          description: 'Auto-Imported: ${parsedTx.merchantName}',
          merchantName: parsedTx.merchantName,
          source: TransactionSource.sms,
          rawSourceText: body,
          dateTime: now,
          isDeleted: false,
          createdAt: now,
          updatedAt: now,
        );

        try {
          await _ref.read(transactionsNotifierProvider.notifier).add(newTx);
          if (context.mounted) {
            context.push('/transactions/$txId');
          }
        } catch (e) {
          debugPrint('Error auto-saving tapped SMS transaction: $e');
        }
      }
    }
  }

  /// Check and import background transaction messages cached in SharedPreferences
  static Future<void> checkAndImportPendingTransactions(WidgetRef ref, BuildContext context) async {
    try {
      final jsonStr = await _channel.invokeMethod<String>('getAndClearPendingTransactions');
      if (jsonStr == null || jsonStr == '[]') return;

      final List<dynamic> list = json.decode(jsonStr);
      if (list.isEmpty) return;

      final accountsAsync = ref.read(accountsNotifierProvider);
      final settingsAsync = ref.read(settingsNotifierProvider);
      final categoriesAsync = ref.read(categoriesNotifierProvider);

      final accounts = accountsAsync.valueOrNull ?? [];
      final appSettings = settingsAsync.valueOrNull;
      final categories = categoriesAsync.valueOrNull ?? [];

      if (accounts.isEmpty) return;

      int importedCount = 0;
      for (final item in list) {
        final sender = item['sender'] as String? ?? 'Unknown';
        final body = item['body'] as String? ?? '';
        
        final parsedTx = await SmsParserService.parseSms(body);
        if (parsedTx != null) {
          final matchedAccount = accounts.firstWhere(
            (a) => parsedTx.accountLastFour != null && a.lastFourDigits != null && a.lastFourDigits!.contains(parsedTx.accountLastFour!),
            orElse: () => accounts.first,
          );
          final nameLower = parsedTx.merchantName.toLowerCase();
          Category? matchedCategory;
          for (final c in categories) {
            if (nameLower.contains(c.name.toLowerCase())) {
              matchedCategory = c;
              break;
            }
          }
          
          final accountId = matchedAccount.id;
          final categoryId = matchedCategory?.id ?? (categories.isNotEmpty ? categories.first.id : 'groceries');

          final bytes = utf8.encode('$sender:$body');
          final txId = sha256.convert(bytes).toString();

          final now = DateTime.now();
          final newTx = Transaction(
            id: txId,
            amount: parsedTx.amount,
            type: parsedTx.type,
            category: categoryId,
            accountId: accountId,
            description: 'Auto-Imported: ${parsedTx.merchantName}',
            merchantName: parsedTx.merchantName,
            source: TransactionSource.sms,
            rawSourceText: body,
            dateTime: now,
            isDeleted: false,
            createdAt: now,
            updatedAt: now,
          );

          await ref.read(transactionsNotifierProvider.notifier).add(newTx);
          importedCount++;
        }
      }

      if (importedCount > 0 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amberAccent),
                const SizedBox(width: 10),
                Text('Auto-imported $importedCount new transactions in background!'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error importing background transactions: $e');
    }
  }

  /// Toggle SMS Broadcast Receiver state in package manager from settings
  static Future<void> syncReceiverStateWithSettings(bool enabled) async {
    try {
      await _channel.invokeMethod('setSmsEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('Error setting SMS receiver component state: $e');
    }
  }
}
