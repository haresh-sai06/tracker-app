import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/currency_wallet.dart';
import 'package:tracker_app/domain/failures/failure.dart';

abstract class CurrencyWalletRepository {
  Future<Either<Failure, List<CurrencyWallet>>> getWallets();
  Future<Either<Failure, CurrencyWallet>> getWallet(String id);
  Future<Either<Failure, void>> addWallet(CurrencyWallet wallet);
  Future<Either<Failure, void>> updateWallet(CurrencyWallet wallet);
  Future<Either<Failure, void>> deleteWallet(String id);
}
