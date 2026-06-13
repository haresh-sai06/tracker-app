import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/account.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/account_repository.dart';
import 'package:tracker_app/data/models/account_model.dart';
import 'package:tracker_app/data/services/database_service.dart';

class AccountRepositoryImpl implements AccountRepository {
  @override
  Future<Either<Failure, List<Account>>> getAccounts({String? currencyCode}) async {
    try {
      final box = DatabaseService.accountsBox;
      var list = box.values
          .map((m) => _toEntity(m))
          .toList();
      if (currencyCode != null && currencyCode.isNotEmpty) {
        list = list.where((acc) => acc.currencyCode == currencyCode).toList();
      }
      return Right(list);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Account>> getAccount(String id) async {
    try {
      final box = DatabaseService.accountsBox;
      final model = box.get(id);
      if (model == null) {
        return const Left(NotFoundFailure('Account not found'));
      }
      return Right(_toEntity(model));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addAccount(Account account) async {
    try {
      final box = DatabaseService.accountsBox;
      await box.put(account.id, _toModel(account));
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateAccount(Account account) async {
    try {
      final box = DatabaseService.accountsBox;
      await box.put(account.id, _toModel(account));
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount(String id) async {
    try {
      final box = DatabaseService.accountsBox;
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

  Account _toEntity(AccountModel model) {
    return Account(
      id: model.id ?? '',
      name: model.name ?? '',
      currencyCode: model.currencyCode ?? 'INR',
      type: _toAccountType(model.type),
      bankName: model.bankName,
      lastFourDigits: model.lastFourDigits,
      isDefault: model.isDefault ?? false,
      isDeleted: model.isDeleted ?? false,
    );
  }

  AccountModel _toModel(Account entity) {
    return AccountModel(
      id: entity.id,
      name: entity.name,
      currencyCode: entity.currencyCode,
      type: _toHiveAccountType(entity.type),
      bankName: entity.bankName,
      lastFourDigits: entity.lastFourDigits,
      isDefault: entity.isDefault,
      isDeleted: entity.isDeleted,
    );
  }

  AccountType _toAccountType(HiveAccountType? type) {
    switch (type) {
      case HiveAccountType.bank:
        return AccountType.bank;
      case HiveAccountType.wallet:
        return AccountType.wallet;
      case HiveAccountType.cash:
        return AccountType.cash;
      case HiveAccountType.credit:
        return AccountType.credit;
      default:
        return AccountType.bank;
    }
  }

  HiveAccountType _toHiveAccountType(AccountType type) {
    switch (type) {
      case AccountType.bank:
        return HiveAccountType.bank;
      case AccountType.wallet:
        return HiveAccountType.wallet;
      case AccountType.cash:
        return HiveAccountType.cash;
      case AccountType.credit:
        return HiveAccountType.credit;
    }
  }
}
