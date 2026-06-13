import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tracker_app/data/services/database_service.dart';
import 'package:tracker_app/data/models/transaction_model.dart';
import 'package:tracker_app/data/models/category_model.dart';
import 'package:tracker_app/data/models/account_model.dart';
import 'package:tracker_app/data/models/currency_wallet_model.dart';

class QuotaExceededException implements Exception {
  final String message;
  QuotaExceededException(this.message);
  @override
  String toString() => message;
}

class AuthExpiredException implements Exception {
  final String message;
  AuthExpiredException(this.message);
  @override
  String toString() => message;
}

class BackupMetadata {
  final DateTime timestamp;
  final int transactionCount;

  BackupMetadata({required this.timestamp, required this.transactionCount});
}

class FirebaseBackupService {
  static const String projectId = String.fromEnvironment('FLUTTER_FIREBASE_PROJECT_ID');
  static const String apiKey = String.fromEnvironment('FLUTTER_FIREBASE_API_KEY');
  static const String baseUrl = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/backups";

  static bool get isConfigured => projectId.isNotEmpty && apiKey.isNotEmpty;

  static String sanitizeBackupKey(String email) {
    return "google-" + email.replaceAll("@", "-at-").replaceAll(".", "-dot-");
  }

  /// Check if backup exists.
  /// Returns null if no backup, or BackupMetadata { timestamp, transactionCount } if found.
  static Future<BackupMetadata?> checkBackupExists(String userId) async {
    if (!isConfigured) {
      debugPrint("[FirebaseBackupService] Firebase credentials are not configured.");
      return null;
    }
    try {
      final key = sanitizeBackupKey(userId);
      final url = Uri.parse("$baseUrl/$key?key=$apiKey");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final doc = jsonDecode(response.body);
        final fields = doc['fields'];
        if (fields == null) return null;

        final dataJsonObj = fields['dataJson'];
        final timestampObj = fields['timestamp'];

        if (dataJsonObj == null || timestampObj == null) return null;

        final rawDataStr = dataJsonObj['stringValue'];
        final timestampStr = timestampObj['stringValue'];
        if (rawDataStr == null || timestampStr == null) return null;

        final payload = jsonDecode(rawDataStr);
        final transactions = payload['transactions'] as List?;
        final txCount = transactions?.length ?? 0;

        final timestampMillis = int.tryParse(timestampStr) ?? DateTime.now().millisecondsSinceEpoch;
        return BackupMetadata(
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMillis),
          transactionCount: txCount,
        );
      } else if (response.statusCode == 404) {
        return null;
      } else {
        debugPrint("[FirebaseBackupService] checkBackupExists response code: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("[FirebaseBackupService] Exception during checkBackupExists: $e");
      return null;
    }
  }

  /// Perform cloud backup.
  /// Backs up Transactions, Categories, Accounts, and Wallets to Firestore document.
  static Future<bool> performBackup(String userId) async {
    if (!isConfigured) {
      debugPrint("[FirebaseBackupService] Firebase credentials are not configured.");
      return false;
    }
    try {
      final key = sanitizeBackupKey(userId);

      // Fetch all local data
      final txs = DatabaseService.transactionsBox.values.toList();
      final cats = DatabaseService.categoriesBox.values.toList();
      final accs = DatabaseService.accountsBox.values.toList();
      final walts = DatabaseService.walletsBox.values.toList();

      final txListJson = txs.map((tx) => {
        'id': tx.id,
        'amount': tx.amount,
        'type': tx.type?.index, // Save enum as index
        'category': tx.category,
        'accountId': tx.accountId,
        'description': tx.description,
        'merchantName': tx.merchantName,
        'source': tx.source?.index,
        'rawSourceText': tx.rawSourceText,
        'dateTime': tx.dateTime?.toIso8601String(),
        'isDeleted': tx.isDeleted,
        'createdAt': tx.createdAt?.toIso8601String(),
        'updatedAt': tx.updatedAt?.toIso8601String(),
        'currencyCode': tx.currencyCode,
      }).toList();

      final catListJson = cats.map((cat) => {
        'id': cat.id,
        'name': cat.name,
        'iconCodePoint': cat.iconCodePoint,
        'colorValue': cat.colorValue,
        'isDefault': cat.isDefault,
        'isDeleted': cat.isDeleted,
      }).toList();

      final accListJson = accs.map((acc) => {
        'id': acc.id,
        'name': acc.name,
        'type': acc.type?.index,
        'bankName': acc.bankName,
        'lastFourDigits': acc.lastFourDigits,
        'isDefault': acc.isDefault,
        'isDeleted': acc.isDeleted,
        'currencyCode': acc.currencyCode,
      }).toList();

      final waltListJson = walts.map((w) => {
        'id': w.id,
        'currencyCode': w.currencyCode,
        'label': w.label,
        'isActive': w.isActive,
        'createdAt': w.createdAt?.toIso8601String(),
      }).toList();

      final payload = {
        'transactions': txListJson,
        'categories': catListJson,
        'accounts': accListJson,
        'wallets': waltListJson,
      };

      final payloadString = jsonEncode(payload);

      final url = Uri.parse("$baseUrl/$key?key=$apiKey");

      final body = {
        "name": "projects/$projectId/databases/(default)/documents/backups/$key",
        "fields": {
          "dataJson": {
            "stringValue": payloadString
          },
          "timestamp": {
            "stringValue": DateTime.now().millisecondsSinceEpoch.toString()
          }
        }
      };

      final response = await http.patch(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        debugPrint("[FirebaseBackupService] Backup successfully uploaded for key: $key");
        return true;
      } else {
        debugPrint("[FirebaseBackupService] Backup failed with status ${response.statusCode}: ${response.body}");
        final responseBody = response.body;
        if (response.statusCode == 403 || responseBody.contains("RESOURCE_EXHAUSTED") || responseBody.contains("quota")) {
          throw QuotaExceededException("Firestore error: ${response.statusCode} - $responseBody");
        } else if (response.statusCode == 401 || responseBody.contains("UNAUTHENTICATED") || responseBody.contains("invalid_grant")) {
          throw AuthExpiredException("Auth expired");
        }
        return false;
      }
    } catch (e) {
      if (e is QuotaExceededException || e is AuthExpiredException) {
        rethrow;
      }
      debugPrint("[FirebaseBackupService] Exception in performBackup: $e");
      return false;
    }
  }

  /// Perform cloud restore.
  /// Downloads backup document and restores Transactions, Categories, Accounts, and Wallets to local Hive.
  static Future<bool> performRestore(String userId) async {
    if (!isConfigured) {
      debugPrint("[FirebaseBackupService] Firebase credentials are not configured.");
      return false;
    }
    try {
      final key = sanitizeBackupKey(userId);
      final url = Uri.parse("$baseUrl/$key?key=$apiKey");
      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint("[FirebaseBackupService] Restore failed: HTTP ${response.statusCode} - ${response.body}");
        final responseBody = response.body;
        if (response.statusCode == 403 || responseBody.contains("RESOURCE_EXHAUSTED") || responseBody.contains("quota")) {
          throw QuotaExceededException("Firestore quota exceeded");
        } else if (response.statusCode == 401 || responseBody.contains("UNAUTHENTICATED") || responseBody.contains("invalid_grant")) {
          throw AuthExpiredException("Auth expired");
        }
        return false;
      }

      final doc = jsonDecode(response.body);
      final fields = doc['fields'];
      if (fields == null) return false;

      final dataJsonObj = fields['dataJson'];
      if (dataJsonObj == null) return false;

      final rawDataStr = dataJsonObj['stringValue'];
      if (rawDataStr == null) return false;

      final payload = jsonDecode(rawDataStr);

      // Clear local boxes first
      await DatabaseService.transactionsBox.clear();
      await DatabaseService.categoriesBox.clear();
      await DatabaseService.accountsBox.clear();
      await DatabaseService.walletsBox.clear();

      final transactions = payload['transactions'] as List?;
      if (transactions != null) {
        for (final item in transactions) {
          final tx = item as Map<String, dynamic>;
          final model = TransactionModel(
            id: tx['id'],
            amount: (tx['amount'] as num?)?.toDouble(),
            type: tx['type'] != null ? HiveTransactionType.values[tx['type'] as int] : null,
            category: tx['category'],
            accountId: tx['accountId'],
            description: tx['description'],
            merchantName: tx['merchantName'],
            source: tx['source'] != null ? HiveTransactionSource.values[tx['source'] as int] : null,
            rawSourceText: tx['rawSourceText'],
            dateTime: tx['dateTime'] != null ? DateTime.parse(tx['dateTime']) : null,
            isDeleted: tx['isDeleted'] as bool?,
            createdAt: tx['createdAt'] != null ? DateTime.parse(tx['createdAt']) : null,
            updatedAt: tx['updatedAt'] != null ? DateTime.parse(tx['updatedAt']) : null,
            currencyCode: tx['currencyCode'],
          );
          await DatabaseService.transactionsBox.put(model.id, model);
        }
      }

      final categories = payload['categories'] as List?;
      if (categories != null) {
        for (final item in categories) {
          final cat = item as Map<String, dynamic>;
          final model = CategoryModel(
            id: cat['id'],
            name: cat['name'],
            iconCodePoint: cat['iconCodePoint'] as int?,
            colorValue: cat['colorValue'] as int?,
            isDefault: cat['isDefault'] as bool?,
            isDeleted: cat['isDeleted'] as bool?,
          );
          await DatabaseService.categoriesBox.put(model.id, model);
        }
      }

      final accounts = payload['accounts'] as List?;
      if (accounts != null) {
        for (final item in accounts) {
          final acc = item as Map<String, dynamic>;
          final model = AccountModel(
            id: acc['id'],
            name: acc['name'],
            type: acc['type'] != null ? HiveAccountType.values[acc['type'] as int] : null,
            bankName: acc['bankName'],
            lastFourDigits: acc['lastFourDigits'],
            isDefault: acc['isDefault'] as bool?,
            isDeleted: acc['isDeleted'] as bool?,
            currencyCode: acc['currencyCode'],
          );
          await DatabaseService.accountsBox.put(model.id, model);
        }
      }

      final wallets = payload['wallets'] as List?;
      if (wallets != null) {
        for (final item in wallets) {
          final w = item as Map<String, dynamic>;
          final model = CurrencyWalletModel(
            id: w['id'],
            currencyCode: w['currencyCode'],
            label: w['label'],
            isActive: w['isActive'] as bool?,
            createdAt: w['createdAt'] != null ? DateTime.parse(w['createdAt']) : null,
          );
          await DatabaseService.walletsBox.put(model.id, model);
        }
      }

      debugPrint("[FirebaseBackupService] Successfully restored data from backup.");
      return true;
    } catch (e) {
      if (e is QuotaExceededException || e is AuthExpiredException) {
        rethrow;
      }
      debugPrint("[FirebaseBackupService] Exception in performRestore: $e");
      return false;
    }
  }
}
