import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/app_settings.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/settings_repository.dart';
import 'package:tracker_app/data/models/settings_model.dart';
import 'package:tracker_app/data/services/database_service.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  @override
  Future<Either<Failure, AppSettings>> getSettings() async {
    try {
      final box = DatabaseService.settingsBox;
      final model = box.get('app_settings');
      if (model == null) {
        return const Left(NotFoundFailure('Settings not found'));
      }
      return Right(_toEntity(model));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateSettings(AppSettings settings) async {
    try {
      final box = DatabaseService.settingsBox;
      await box.put('app_settings', _toModel(settings));
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> getActiveCurrencyCode() async {
    try {
      final box = DatabaseService.settingsBox;
      final savedCode = box.get('active_currency_code') as String?;
      if (savedCode != null && savedCode.isNotEmpty) {
        return Right(savedCode);
      }
      final model = box.get('app_settings');
      final defaultCode = model?.defaultCurrencyCode ?? 'INR';
      return Right(defaultCode);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setActiveCurrencyCode(String code) async {
    try {
      final box = DatabaseService.settingsBox;
      await box.put('active_currency_code', code);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  AppSettings _toEntity(SettingsModel model) {
    return AppSettings(
      isBiometricEnabled: model.isBiometricEnabled ?? false,
      isSmsParsingEnabled: model.isSmsParsingEnabled ?? false,
      isNotificationListenerEnabled: model.isNotificationListenerEnabled ?? false,
      isGmailSyncEnabled: model.isGmailSyncEnabled ?? false,
      defaultAccountId: model.defaultAccountId,
      defaultCurrencyCode: model.defaultCurrencyCode ?? 'USD',
      themeMode: model.themeMode ?? 'system',
      userName: model.userName,
      userPhotoPath: model.userPhotoPath,
    );
  }

  SettingsModel _toModel(AppSettings entity) {
    return SettingsModel(
      isBiometricEnabled: entity.isBiometricEnabled,
      isSmsParsingEnabled: entity.isSmsParsingEnabled,
      isNotificationListenerEnabled: entity.isNotificationListenerEnabled,
      isGmailSyncEnabled: entity.isGmailSyncEnabled,
      defaultAccountId: entity.defaultAccountId,
      defaultCurrencyCode: entity.defaultCurrencyCode,
      themeMode: entity.themeMode,
      userName: entity.userName,
      userPhotoPath: entity.userPhotoPath,
      version: DatabaseService.currentDbVersion,
    );
  }
}
