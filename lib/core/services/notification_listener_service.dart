import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_app/core/services/notification_parser_service.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/entities/category.dart';
import 'package:tracker_app/presentation/providers/accounts_provider.dart';
import 'package:tracker_app/presentation/providers/categories_provider.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';
import 'package:tracker_app/presentation/providers/settings_provider.dart';

final notificationListenerServiceProvider = Provider<NotificationListenerService>((ref) {
  return NotificationListenerService(ref);
});

class NotificationListenerService {
  final Ref _ref;
  static const _channel = MethodChannel('com.yourapp.tracker/notifications');
  bool _isInitialized = false;

  NotificationListenerService(this._ref);

  /// Initializes the MethodChannel handler to receive onNotificationReceived calls.
  void initialize(BuildContext context) {
    if (_isInitialized) return;
    _isInitialized = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onNotificationReceived':
          final map = call.arguments as Map?;
          if (map != null) {
            final packageName = map['packageName'] as String? ?? '';
            final title = map['title'] as String? ?? '';
            final text = map['text'] as String? ?? '';
            _handleIncomingNotification(context, packageName, title, text);
          }
          break;
      }
    });
  }

  /// Check whether the system permission Settings > Notification Access is granted.
  static Future<bool> isPermissionGranted() async {
    try {
      final grs = await _channel.invokeMethod<bool>('isNotificationListenerGranted');
      return grs ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Launch the Settings system page to request listener access from the user.
  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationListenerPermission');
    } catch (e) {
      debugPrint('Error launching notification listener settings: $e');
    }
  }

  /// Parses incoming notification matching bank app packages and opens review if matched.
  Future<void> _handleIncomingNotification(
    BuildContext context,
    String packageName,
    String title,
    String text,
  ) async {
    debugPrint('[NotificationListener] Received event from $packageName - Title: "$title", Text: "$text"');
    final settings = _ref.read(settingsNotifierProvider).valueOrNull;
    if (settings == null) {
      debugPrint('[NotificationListener] Settings is null, ignoring.');
      return;
    }
    if (!settings.isNotificationListenerEnabled) {
      debugPrint('[NotificationListener] Notification listener is disabled in settings, ignoring.');
      return;
    }

    final parsedTx = await NotificationParserService.parseNotification(
      packageName: packageName,
      title: title,
      text: text,
    );

    if (parsedTx == null) {
      debugPrint('[NotificationListener] Failed to parse transaction from: "$title: $text"');
      return;
    }

    debugPrint('[NotificationListener] Parsed transaction successfully! Amount: ${parsedTx.amount}, Merchant: ${parsedTx.merchantName}');

    // Auto-insert transaction directly into database
    final accountsAsync = _ref.read(accountsNotifierProvider);
    final categoriesAsync = _ref.read(categoriesNotifierProvider);
    final accounts = accountsAsync.valueOrNull ?? [];
    final categories = categoriesAsync.valueOrNull ?? [];

    if (accounts.isEmpty) {
      debugPrint('[NotificationListener] Accounts list is empty! Cannot save transaction.');
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

        // Generate deterministic ID using hash of package + title + text
        final bytes = utf8.encode('$packageName:$title:$text');
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
          source: TransactionSource.notification,
          rawSourceText: text.isNotEmpty ? text : '$title: $text',
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
                backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                action: SnackBarAction(
                  label: 'EDIT',
                  textColor: Theme.of(context).colorScheme.onTertiaryContainer,
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
}
