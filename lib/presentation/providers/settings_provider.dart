import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tracker_app/domain/entities/app_settings.dart';
import 'package:tracker_app/presentation/providers/repository_providers.dart';
import 'package:tracker_app/core/services/data_management_service.dart';
import 'package:tracker_app/presentation/providers/accounts_provider.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';
import 'package:tracker_app/presentation/providers/categories_provider.dart';
import 'package:tracker_app/core/services/auto_sync_service.dart';

part 'settings_provider.g.dart';

@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  @override
  FutureOr<AppSettings> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    final result = await repo.getSettings();
    return result.fold(
      (failure) => const AppSettings(
        isBiometricEnabled: false,
        isSmsParsingEnabled: false,
        isNotificationListenerEnabled: false,
        isGmailSyncEnabled: false,
        defaultAccountId: 'primary_bank',
        defaultCurrencyCode: 'USD',
        themeMode: 'system',
      ),
      (settings) => settings,
    );
  }

  Future<void> updateSettings(AppSettings settings) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.updateSettings(settings);
      
      // Schedule auto sync on settings change
      ref.read(autoSyncServiceProvider).scheduleSync();
      
      return settings;
    });
  }

  Future<void> updateSetting<T>(String key, T value) async {
    final current = state.valueOrNull;
    if (current == null) return;
    
    AppSettings updated;
    switch (key) {
      case 'isBiometricEnabled':
        updated = current.copyWith(isBiometricEnabled: value as bool);
        break;
      case 'isSmsParsingEnabled':
        updated = current.copyWith(isSmsParsingEnabled: value as bool);
        break;
      case 'isNotificationListenerEnabled':
        updated = current.copyWith(isNotificationListenerEnabled: value as bool);
        break;
      case 'isGmailSyncEnabled':
        updated = current.copyWith(isGmailSyncEnabled: value as bool);
        break;
      case 'defaultAccountId':
        updated = current.copyWith(defaultAccountId: value as String?);
        break;
      case 'defaultCurrencyCode':
        updated = current.copyWith(defaultCurrencyCode: value as String);
        break;
      case 'themeMode':
        updated = current.copyWith(themeMode: value as String);
        break;
      case 'userName':
        updated = current.copyWith(userName: value as String?);
        break;
      case 'userPhotoPath':
        updated = current.copyWith(userPhotoPath: value as String?);
        break;
      default:
        return;
    }
    
    await updateSettings(updated);
  }

  Future<void> clearAllData() async {
    state = const AsyncValue.loading();
    await DataManagementService.clearAllData();
    
    // Invalidate other major cache providers to reload from the new seed database
    ref.invalidate(accountsNotifierProvider);
    ref.invalidate(transactionsNotifierProvider);
    ref.invalidate(categoriesNotifierProvider);
    
    // Refresh self
    ref.invalidateSelf();
  }
}

