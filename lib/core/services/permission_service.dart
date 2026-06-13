import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Check the current status of the SMS permission.
  static Future<PermissionStatus> checkSmsPermission() async {
    return await Permission.sms.status;
  }

  /// Request SMS permissions and return whether they were successfully granted.
  static Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Check if notification permission (used also in phase 11 for logs/notification listeners) is enabled.
  static Future<bool> checkNotificationListenerPermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    
    // In Android, notifications are often auto-allowed on older versions. On newer Android,
    // we want to ask for permissions carefully.
    return status == PermissionStatus.granted;
  }
}
