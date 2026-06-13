import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tracker_app/core/services/biometric_service.dart';
import 'package:tracker_app/core/services/notification_listener_service.dart';
import 'package:tracker_app/core/services/permission_service.dart';
import 'package:tracker_app/core/services/sms_listener_service.dart';
import 'package:tracker_app/core/services/app_health_service.dart';
import 'package:tracker_app/presentation/providers/settings_provider.dart';

part 'permissions_provider.g.dart';

class PermissionsState {
  final bool smsGranted;
  final bool notificationListenerEnabled;
  final bool biometricAvailable;
  final bool storageGranted;

  const PermissionsState({
    required this.smsGranted,
    required this.notificationListenerEnabled,
    required this.biometricAvailable,
    required this.storageGranted,
  });

  PermissionsState copyWith({
    bool? smsGranted,
    bool? notificationListenerEnabled,
    bool? biometricAvailable,
    bool? storageGranted,
  }) {
    return PermissionsState(
      smsGranted: smsGranted ?? this.smsGranted,
      notificationListenerEnabled: notificationListenerEnabled ?? this.notificationListenerEnabled,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      storageGranted: storageGranted ?? this.storageGranted,
    );
  }

  @override
  String toString() {
    return 'PermissionsState(smsGranted: $smsGranted, notificationListenerEnabled: $notificationListenerEnabled, biometricAvailable: $biometricAvailable, storageGranted: $storageGranted)';
  }
}

@riverpod
class PermissionsNotifier extends _$PermissionsNotifier {
  @override
  FutureOr<PermissionsState> build() async {
    final permissions = await _checkAllPermissions();
    _handleAutoDegradation(permissions);
    return permissions;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final permissions = await _checkAllPermissions();
      await _handleAutoDegradation(permissions);
      return permissions;
    });
  }

  Future<void> _handleAutoDegradation(PermissionsState permissions) async {
    // 1. Auto-degradation check for biometric lock if it was removed/disabled in system setting
    if (!permissions.biometricAvailable) {
      final settings = ref.read(settingsNotifierProvider).valueOrNull;
      if (settings != null && settings.isBiometricEnabled) {
        // Record auto disabled recently in session
        ref.read(biometricAutoDisabledProvider.notifier).state = true;
        // Auto disable biometric lock in AppSettings without prompt
        await ref.read(settingsNotifierProvider.notifier).updateSetting('isBiometricEnabled', false);
      }
    }

    // 2. SMS permission revoked -> disable SmsListenerService Receiver silently
    if (!permissions.smsGranted) {
      final settings = ref.read(settingsNotifierProvider).valueOrNull;
      if (settings != null && settings.isSmsParsingEnabled) {
        await SmsListenerService.syncReceiverStateWithSettings(false);
      }
    }
  }

  Future<PermissionsState> _checkAllPermissions() async {
    // 1. Check SMS status
    final smsStatus = await PermissionService.checkSmsPermission();
    final smsGranted = smsStatus.isGranted;

    // 2. Check Notification Listener setup
    final notificationListenerEnabled = await NotificationListenerService.isPermissionGranted();

    // 3. Check Biometrics availability
    final biometricService = BiometricService();
    final biometricAvailable = await biometricService.isAvailable();

    // 4. Check Storage (Older devices: SDK < 29)
    bool storageGranted = true;
    if (Platform.isAndroid) {
      try {
        final version = Platform.operatingSystemVersion;
        final sdkMatch = RegExp(r'(?:SDK|API)\s+(\d+)', caseSensitive: false).firstMatch(version);
        if (sdkMatch != null) {
          final sdk = int.parse(sdkMatch.group(1)!);
          if (sdk < 29) {
            final status = await Permission.storage.status;
            storageGranted = status.isGranted;
          }
        }
      } catch (_) {
        final status = await Permission.storage.status;
        storageGranted = status.isGranted;
      }
    }

    return PermissionsState(
      smsGranted: smsGranted,
      notificationListenerEnabled: notificationListenerEnabled,
      biometricAvailable: biometricAvailable,
      storageGranted: storageGranted,
    );
  }
}

