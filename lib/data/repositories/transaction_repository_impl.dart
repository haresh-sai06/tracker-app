import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/transaction_repository.dart';
import 'package:tracker_app/data/models/transaction_model.dart';
import 'package:tracker_app/data/services/database_service.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  @override
  Future<Either<Failure, List<Transaction>>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? accountId,
    TransactionType? type,
    String? searchQuery,
    String? currencyCode,
  }) async {
    try {
      final box = DatabaseService.transactionsBox;
      var queryResults = box.values.where((m) => m.isDeleted != true);

      if (startDate != null) {
        queryResults = queryResults.where((m) {
          if (m.dateTime == null) return false;
          return m.dateTime!.isAfter(startDate) || m.dateTime!.isAtSameMomentAs(startDate);
        });
      }
      if (endDate != null) {
        queryResults = queryResults.where((m) {
          if (m.dateTime == null) return false;
          return m.dateTime!.isBefore(endDate) || m.dateTime!.isAtSameMomentAs(endDate);
        });
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        queryResults = queryResults.where((m) => m.category == categoryId);
      }
      if (accountId != null && accountId.isNotEmpty) {
        queryResults = queryResults.where((m) => m.accountId == accountId);
      }
      if (type != null) {
        final hiveType = _toHiveTransactionType(type);
        queryResults = queryResults.where((m) => m.type == hiveType);
      }
      if (currencyCode != null && currencyCode.isNotEmpty) {
        queryResults = queryResults.where((m) => m.currencyCode == currencyCode);
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.toLowerCase().trim();
        queryResults = queryResults.where((m) =>
            (m.description != null && m.description!.toLowerCase().contains(query)) ||
            (m.merchantName != null && m.merchantName!.toLowerCase().contains(query)));
      }

      final list = queryResults.map((m) => _toEntity(m)).toList();
      return Right(list);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Transaction>> getTransaction(String id) async {
    try {
      final box = DatabaseService.transactionsBox;
      final model = box.get(id);
      if (model == null || model.isDeleted == true) {
        return const Left(NotFoundFailure('Transaction not found'));
      }
      return Right(_toEntity(model));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addTransaction(Transaction transaction) async {
    try {
      final settingsBox = DatabaseService.settingsBox;
      final savedActiveCode = settingsBox.get('active_currency_code') as String?;
      String activeCurrencyCode = 'INR';
      if (savedActiveCode != null && savedActiveCode.isNotEmpty) {
        activeCurrencyCode = savedActiveCode;
      } else {
        final settingsModel = settingsBox.get('app_settings');
        if (settingsModel != null) {
          activeCurrencyCode = settingsModel.defaultCurrencyCode ?? 'INR';
        }
      }

      if (transaction.currencyCode != activeCurrencyCode) {
        final errorMsg = "Currency mismatch: attempted to save [${transaction.currencyCode}] transaction into [$activeCurrencyCode] wallet.";
        // Log this as warning in debug mode
        assert(() {
          print("WARNING: $errorMsg");
          return true;
        }());
        return Left(DatabaseFailure(errorMsg));
      }

      final box = DatabaseService.transactionsBox;
      await box.put(transaction.id, _toModel(transaction));
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateTransaction(Transaction transaction) async {
    try {
      final box = DatabaseService.transactionsBox;
      await box.put(transaction.id, _toModel(transaction));
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTransaction(String id) async {
    try {
      final box = DatabaseService.transactionsBox;
      final model = box.get(id);
      if (model != null) {
        model.isDeleted = true;
        await model.save();
      }
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Transaction>>> getTransactionsByCurrency(String currencyCode) async {
    try {
      final box = DatabaseService.transactionsBox;
      final queryResults = box.values
          .where((m) => m.isDeleted != true && m.currencyCode == currencyCode)
          .map((m) => _toEntity(m))
          .toList();
      return Right(queryResults);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  Transaction _toEntity(TransactionModel model) {
    return Transaction(
      id: model.id ?? '',
      amount: model.amount ?? 0.0,
      currencyCode: model.currencyCode ?? 'INR',
      type: _toTransactionType(model.type),
      category: model.category ?? '',
      accountId: model.accountId ?? '',
      description: model.description ?? '',
      merchantName: model.merchantName,
      source: _toTransactionSource(model.source),
      rawSourceText: model.rawSourceText,
      dateTime: model.dateTime ?? DateTime.now(),
      isDeleted: model.isDeleted ?? false,
      createdAt: model.createdAt ?? DateTime.now(),
      updatedAt: model.updatedAt ?? DateTime.now(),
    );
  }

  TransactionModel _toModel(Transaction entity) {
    return TransactionModel(
      id: entity.id,
      amount: entity.amount,
      currencyCode: entity.currencyCode,
      type: _toHiveTransactionType(entity.type),
      category: entity.category,
      accountId: entity.accountId,
      description: entity.description,
      merchantName: entity.merchantName,
      source: _toHiveTransactionSource(entity.source),
      rawSourceText: entity.rawSourceText,
      dateTime: entity.dateTime,
      isDeleted: entity.isDeleted,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  TransactionType _toTransactionType(HiveTransactionType? type) {
    switch (type) {
      case HiveTransactionType.credit:
        return TransactionType.credit;
      case HiveTransactionType.debit:
        return TransactionType.debit;
      default:
        return TransactionType.debit;
    }
  }

  HiveTransactionType _toHiveTransactionType(TransactionType type) {
    switch (type) {
      case TransactionType.credit:
        return HiveTransactionType.credit;
      case TransactionType.debit:
        return HiveTransactionType.debit;
    }
  }

  TransactionSource _toTransactionSource(HiveTransactionSource? source) {
    switch (source) {
      case HiveTransactionSource.manual:
        return TransactionSource.manual;
      case HiveTransactionSource.sms:
        return TransactionSource.sms;
      case HiveTransactionSource.notification:
        return TransactionSource.notification;
      case HiveTransactionSource.email:
        return TransactionSource.email;
      default:
        return TransactionSource.manual;
    }
  }

  HiveTransactionSource _toHiveTransactionSource(TransactionSource source) {
    switch (source) {
      case TransactionSource.manual:
        return HiveTransactionSource.manual;
      case TransactionSource.sms:
        return HiveTransactionSource.sms;
      case TransactionSource.notification:
        return HiveTransactionSource.notification;
      case TransactionSource.email:
        return HiveTransactionSource.email;
    }
  }
}
