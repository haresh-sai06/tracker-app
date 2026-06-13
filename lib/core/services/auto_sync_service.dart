import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_app/core/services/gmail_sync_service.dart';
import 'package:tracker_app/core/services/firebase_backup_service.dart';
import 'package:tracker_app/data/services/database_service.dart';

enum SyncStatus { idle, syncing, success, error }
enum SyncErrorState { none, quotaExceeded, authExpired, networkError }

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);
final syncStatusMessageProvider = StateProvider<String?>((ref) => null);
final syncErrorStateProvider = StateProvider<SyncErrorState>((ref) => SyncErrorState.none);

// Restore progress state providers
final isRestoringProvider = StateProvider<bool>((ref) => false);
final restoreMessageProvider = StateProvider<String>((ref) => "Restoring your data...");
final restoreProgressCountProvider = StateProvider<int?>((ref) => null);

class AutoSyncService {
  final Ref _ref;
  Timer? _debounceTimer;

  AutoSyncService(this._ref);

  bool get isEnabled {
    final user = GmailSyncService.currentUser;
    return user != null;
  }

  DateTime? get lastSyncedAt {
    final raw = DatabaseService.settingsBox.get('auto_sync_last_synced_at');
    if (raw != null && raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  void scheduleSync() {
    if (!isEnabled) {
      debugPrint("[AutoSyncService] AutoSync check failed: not enabled or user not signed in.");
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      _executeSync();
    });
  }

  Future<void> syncNow() async {
    _debounceTimer?.cancel();
    await _executeSync();
  }

  Future<void> _executeSync() async {
    final user = GmailSyncService.currentUser;
    if (user == null) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      _ref.read(syncStatusMessageProvider.notifier).state = "No Google account connected.";
      _ref.read(syncErrorStateProvider.notifier).state = SyncErrorState.authExpired;
      return;
    }

    _ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
    _ref.read(syncStatusMessageProvider.notifier).state = "Syncing...";
    _ref.read(syncErrorStateProvider.notifier).state = SyncErrorState.none;

    // 1. Check offline status first
    try {
      final lookup = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 4));
      if (lookup.isEmpty || lookup[0].rawAddress.isEmpty) {
        throw const SocketException("No internet connection.");
      }
    } catch (_) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      _ref.read(syncStatusMessageProvider.notifier).state = "Offline — will sync when connected";
      _ref.read(syncErrorStateProvider.notifier).state = SyncErrorState.networkError;
      debugPrint("[AutoSyncService] Sync aborted: Device is offline.");
      return;
    }

    // 2. Perform backup
    try {
      final success = await FirebaseBackupService.performBackup(user.email);
      if (success) {
        final now = DateTime.now();
        await DatabaseService.settingsBox.put('auto_sync_last_synced_at', now.toIso8601String());
        await DatabaseService.settingsBox.put('gmail_last_sync_tx_count', DatabaseService.transactionsBox.length);
        _ref.read(syncStatusProvider.notifier).state = SyncStatus.success;
        _ref.read(syncStatusMessageProvider.notifier).state = null;
        _ref.read(syncErrorStateProvider.notifier).state = SyncErrorState.none;
        debugPrint("[AutoSyncService] AutoSync completed successfully.");
      } else {
        _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
        _ref.read(syncStatusMessageProvider.notifier).state = "Sync failed.";
        _ref.read(syncErrorStateProvider.notifier).state = SyncErrorState.none;
        debugPrint("[AutoSyncService] AutoSync failed.");
      }
    } on QuotaExceededException catch (e) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      _ref.read(syncStatusMessageProvider.notifier).state = e.message;
      _ref.read(syncErrorStateProvider.notifier).state = SyncErrorState.quotaExceeded;
      debugPrint("[AutoSyncService] Quota exceeded: $e");
    } on AuthExpiredException catch (e) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      _ref.read(syncStatusMessageProvider.notifier).state = "Sign in again to resume sync.";
      _ref.read(syncErrorStateProvider.notifier).state = SyncErrorState.authExpired;
      debugPrint("[AutoSyncService] Auth expired: $e");
    } catch (e) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      _ref.read(syncStatusMessageProvider.notifier).state = "Sync error: $e";
      _ref.read(syncErrorStateProvider.notifier).state = SyncErrorState.none;
      debugPrint("[AutoSyncService] AutoSync error: $e");
    }
  }
}

final autoSyncServiceProvider = Provider<AutoSyncService>((ref) {
  return AutoSyncService(ref);
});
