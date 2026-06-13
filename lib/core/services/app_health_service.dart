import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_app/domain/entities/app_settings.dart';
import 'package:tracker_app/presentation/providers/permissions_provider.dart';
import 'package:tracker_app/core/services/notification_listener_service.dart';

// Session-level provider to track if we auto-disabled biometric lock recently due to hardware removal
final biometricAutoDisabledProvider = StateProvider<bool>((ref) => false);
final dismissedHealthIssuesProvider = StateProvider<Set<String>>((ref) => <String>{});

class HealthIssue {
  final String feature;
  final String message;
  final String actionLabel;
  final VoidCallback action;

  const HealthIssue({
    required this.feature,
    required this.message,
    required this.actionLabel,
    required this.action,
  });
}

class AppHealthService {
  static List<HealthIssue> checkHealth({
    required AppSettings settings,
    required PermissionsState permissions,
    required BuildContext context,
    required WidgetRef ref,
  }) {
    final issues = <HealthIssue>[];

    // 1. SMS Auto-Import enabled but SMS system permissions revoked
    if (settings.isSmsParsingEnabled && !permissions.smsGranted) {
      issues.add(
        HealthIssue(
          feature: 'SMS',
          message: 'SMS permission has been revoked. Auto-parsing is temporarily disabled.',
          actionLabel: 'Grant Access',
          action: () {
            context.push('/permissions/sms');
          },
        ),
      );
    }

    // 2. Notification Listener enabled but notification access permission revoked
    if (settings.isNotificationListenerEnabled && !permissions.notificationListenerEnabled) {
      issues.add(
        HealthIssue(
          feature: 'Notification Listener',
          message: 'App notification access is disabled. Swipe alert parsing is inactive.',
          actionLabel: 'Grant Access',
          action: () {
            NotificationListenerService.requestPermission();
          },
        ),
      );
    }

    // 3. Biometric removed from device -> auto-disable biometric lock, show settings banner
    final biometricAutoDisabled = ref.read(biometricAutoDisabledProvider);
    if (biometricAutoDisabled) {
      issues.add(
        HealthIssue(
          feature: 'Security',
          message: 'Biometric settings removed from device. PIN / Fingerprint lock auto-disabled for safety.',
          actionLabel: 'Settings',
          action: () {
            context.push('/settings');
          },
        ),
      );
    }

    return issues;
  }
}
