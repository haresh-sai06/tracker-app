import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:tracker_app/core/services/gmail_sync_service.dart';
import 'package:tracker_app/core/services/firebase_backup_service.dart';
import 'package:tracker_app/presentation/providers/settings_provider.dart';
import 'package:tracker_app/presentation/providers/accounts_provider.dart';
import 'package:tracker_app/presentation/providers/categories_provider.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';
import 'package:tracker_app/core/services/auto_sync_service.dart';
import 'package:tracker_app/data/services/database_service.dart';

class GoogleSyncCard extends ConsumerStatefulWidget {
  const GoogleSyncCard({super.key});

  @override
  ConsumerState<GoogleSyncCard> createState() => _GoogleSyncCardState();
}

class _GoogleSyncCardState extends ConsumerState<GoogleSyncCard> {
  GoogleSignInAccount? _googleUser;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _loadingMessage;
  String? _lastSyncTime;
  int _lastSyncCount = 0;
  int? _transactionsBackedUp;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  void _loadState() {
    final box = DatabaseService.settingsBox;
    _lastSyncTime = box.get('gmail_last_sync_time');
    _lastSyncCount = box.get('gmail_last_sync_tx_count', defaultValue: 0);
    _checkGoogleConnection();
  }

  Future<void> _checkGoogleConnection() async {
    setState(() => _isLoading = true);
    try {
      final user = await GmailSyncService.getConnectedAccount();
      setState(() {
        _googleUser = user;
      });
      if (user != null) {
        final backupInfo = await FirebaseBackupService.checkBackupExists(user.email);
        if (mounted) {
          setState(() {
            _transactionsBackedUp = backupInfo?.transactionCount;
          });
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _connectGmail() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = "Checking for sync profile...";
    });
    try {
      final user = await GmailSyncService.signIn();
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadingMessage = null;
          });
        }
        return;
      }

      setState(() {
        _googleUser = user;
      });

      // Call checkBackupExists
      final backupInfo = await FirebaseBackupService.checkBackupExists(user.email);

      if (mounted) {
        if (backupInfo != null) {
          // Backup found! Show a non-dismissible dialog
          final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(backupInfo.timestamp);
          final restoreNow = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return PopScope(
                canPop: false,
                child: AlertDialog(
                  title: const Text('Saved profile found'),
                  content: Text('Saved data from $formattedDate was found with ${backupInfo.transactionCount} transactions. Synchronize it now?'),
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Start fresh'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Restore'),
                    ),
                  ],
                ),
              );
            },
          );

          if (restoreNow == true) {
            setState(() {
              _isLoading = true;
              _loadingMessage = "Recovering synchronized data...";
            });

            final restoreSuccess = await FirebaseBackupService.performRestore(user.email);
            if (restoreSuccess) {
              ref.invalidate(accountsNotifierProvider);
              ref.invalidate(transactionsNotifierProvider);
              ref.invalidate(categoriesNotifierProvider);
              ref.invalidate(settingsNotifierProvider);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Successfully synchronized and recovered all your data!'), backgroundColor: Colors.teal),
                );
                context.go('/dashboard');
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to synchronize data. Proceeding with local data.'), backgroundColor: Colors.orangeAccent),
                );
              }
            }
          } else {
            // "Start fresh" chosen
            setState(() {
              _isLoading = true;
              _loadingMessage = "Initializing fresh profile...";
            });
            await ref.read(settingsNotifierProvider.notifier).clearAllData();
            // Start sync (creating initial document)
            await FirebaseBackupService.performBackup(user.email);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Started fresh. Empty database initialized and synced.'), backgroundColor: Colors.teal),
              );
            }
          }
        } else {
          // No backup exists
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signed in. Your database will be synchronized automatically.'), backgroundColor: Colors.teal),
          );
          // Immediately performBackup() to create initial document
          await FirebaseBackupService.performBackup(user.email);
        }

        final backupInfoNew = await FirebaseBackupService.checkBackupExists(user.email);
        if (mounted) {
          setState(() {
            _transactionsBackedUp = backupInfoNew?.transactionCount;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In or sync failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = null;
        });
      }
    }
  }

  Future<void> _disconnectGmail() async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Gmail?'),
        content: const Text(
          'This will revoke App access to read bank emails, clear your local email cache logs, and reset sync history from your device. Existing transaction entries will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
        _loadingMessage = "Disconnecting...";
      });
      try {
        await GmailSyncService.disconnectGmail();
        _loadState();
        setState(() {
          _googleUser = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your local data is safe. Cloud sync has been disabled.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to disconnect: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadingMessage = null;
          });
        }
      }
    }
  }

  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return "Never synced";
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) {
      return "Last synced: Just now";
    } else if (diff.inMinutes < 60) {
      return "Last synced: ${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago";
    } else if (diff.inHours < 24) {
      return "Last synced: ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago";
    } else {
      return "Last synced: ${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = _googleUser != null;
    final syncStatus = ref.watch(syncStatusProvider);
    final autoSyncService = ref.read(autoSyncServiceProvider);

    if (_isLoading) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _loadingMessage ?? 'Loading...',
                style: const TextStyle(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!isConnected) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.offline_bolt_rounded,
                    color: theme.colorScheme.outline,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Disconnected',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'Requires authenticated login to check emails and sync',
                          style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _connectGmail,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Connect Google Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: (_googleUser?.photoUrl != null && _googleUser!.photoUrl!.isNotEmpty)
                      ? NetworkImage(_googleUser!.photoUrl!)
                      : null,
                  child: (_googleUser?.photoUrl == null || _googleUser!.photoUrl!.isEmpty)
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _googleUser?.displayName ?? 'Google User',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _googleUser?.email ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Auto-sync: On',
                    style: TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                syncStatus == SyncStatus.syncing
                    ? const _AnimatedSyncIcon()
                    : Icon(Icons.cloud_done, color: theme.colorScheme.outline, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        syncStatus == SyncStatus.error
                            ? "Sync Failed"
                            : _formatTimeAgo(autoSyncService.lastSyncedAt),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: syncStatus == SyncStatus.error ? theme.colorScheme.error : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        syncStatus == SyncStatus.error
                            ? (ref.watch(syncStatusMessageProvider) ?? "Unknown error occurred.")
                            : "Transactions synchronized: ${_transactionsBackedUp ?? DatabaseService.settingsBox.get('gmail_last_sync_tx_count', defaultValue: 0)}",
                        style: TextStyle(
                          color: syncStatus == SyncStatus.error ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: (syncStatus == SyncStatus.syncing || _isSyncing)
                      ? null
                      : () async {
                          setState(() => _isSyncing = true);
                          await ref.read(autoSyncServiceProvider).syncNow();
                          final user = GmailSyncService.currentUser;
                          if (user != null) {
                            final backupInfo = await FirebaseBackupService.checkBackupExists(user.email);
                            if (mounted) {
                              setState(() {
                                _transactionsBackedUp = backupInfo?.transactionCount ?? DatabaseService.settingsBox.get('gmail_last_sync_tx_count', defaultValue: 0);
                              });
                            }
                          }
                          setState(() => _isSyncing = false);
                        },
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sync now'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: _disconnectGmail,
                  icon: const Icon(Icons.power_settings_new, size: 16),
                  label: const Text('Disconnect'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedSyncIcon extends StatefulWidget {
  const _AnimatedSyncIcon();

  @override
  _AnimatedSyncIconState createState() => _AnimatedSyncIconState();
}

class _AnimatedSyncIconState extends State<_AnimatedSyncIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(Icons.sync_rounded, color: Colors.teal, size: 20),
    );
  }
}
