import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/currency_wallet.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/currency_wallet_repository.dart';
import 'package:tracker_app/data/models/currency_wallet_model.dart';
import 'package:tracker_app/data/services/database_service.dart';

class CurrencyWalletRepositoryImpl implements CurrencyWalletRepository {
  @override
  Future<Either<Failure, List<CurrencyWallet>>> getWallets() async {
    try {
      final box = DatabaseService.walletsBox;
      final list = box.values
          .map((m) => _toEntity(m))
          .toList();
      return Right(list);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CurrencyWallet>> getWallet(String id) async {
    try {
      final box = DatabaseService.walletsBox;
      final model = box.get(id);
      if (model == null) {
        return const Left(NotFoundFailure('Wallet not found'));
      }
      return Right(_toEntity(model));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addWallet(CurrencyWallet wallet) async {
    try {
      final box = DatabaseService.walletsBox;
      await box.put(wallet.id, _toModel(wallet));
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateWallet(CurrencyWallet wallet) async {
    try {
      final box = DatabaseService.walletsBox;
      await box.put(wallet.id, _toModel(wallet));
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteWallet(String id) async {
    try {
      final box = DatabaseService.walletsBox;
      await box.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  CurrencyWallet _toEntity(CurrencyWalletModel model) {
    return CurrencyWallet(
      id: model.id ?? '',
      currencyCode: model.currencyCode ?? '',
      label: model.label ?? '',
      isActive: model.isActive ?? false,
      createdAt: model.createdAt ?? DateTime.now(),
    );
  }

  CurrencyWalletModel _toModel(CurrencyWallet entity) {
    return CurrencyWalletModel(
      id: entity.id,
      currencyCode: entity.currencyCode,
      label: entity.label,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }
}
