import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/app_settings.dart';
import 'package:tracker_app/domain/failures/failure.dart';

abstract class SettingsRepository {
  Future<Either<Failure, AppSettings>> getSettings();
  Future<Either<Failure, void>> updateSettings(AppSettings settings);
  Future<Either<Failure, String>> getActiveCurrencyCode();
  Future<Either<Failure, void>> setActiveCurrencyCode(String code);
}
