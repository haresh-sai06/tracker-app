import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:tracker_app/core/services/gmail_sync_service.dart';
import 'package:tracker_app/data/services/database_service.dart';
import 'package:tracker_app/core/services/firebase_backup_service.dart';
import 'package:tracker_app/presentation/providers/settings_provider.dart';
import 'package:tracker_app/presentation/providers/accounts_provider.dart';
import 'package:tracker_app/presentation/providers/categories_provider.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';
import 'package:tracker_app/core/services/auto_sync_service.dart';

class GmailSyncPage extends ConsumerStatefulWidget {
  const GmailSyncPage({super.key});

  @override
  ConsumerState<GmailSyncPage> createState() => _GmailSyncPageState();
}

class _GmailSyncPageState extends ConsumerState<GmailSyncPage> {
  GoogleSignInAccount? _googleUser;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _loadingMessage;
  List<Map<String, dynamic>> _scannedEmails = [];
  List<String> _senderDomains = [];
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

    final rawEmails = box.get('gmail_scanned_emails');
    if (rawEmails != null && rawEmails is List) {
      _scannedEmails = List<Map<String, dynamic>>.from(
        rawEmails.map((e) => Map<String, dynamic>.from(e))
      );
    } else {
      _scannedEmails = [];
    }

    _senderDomains = List<String>.from(
      box.get('gmail_sender_domains', defaultValue: GmailSyncService.defaultSenders)
    );

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
            barrierDismissible: false, // non-dismissible
            builder: (context) {
              return PopScope(
                canPop: false, // non-dismissible via back button
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

        final freshBackupInfo = await FirebaseBackupService.checkBackupExists(user.email);
        if (mounted) {
          setState(() {
            _transactionsBackedUp = freshBackupInfo?.transactionCount;
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

  Future<void> _syncNow() async {
    if (_googleUser == null) return;
    setState(() => _isSyncing = true);
    try {
      final parsedTxs = await GmailSyncService.syncTransactions();
      _loadState(); // Refresh scanned logs and sync values

      if (mounted) {
        if (parsedTxs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Matched ${parsedTxs.length} credit/debit transaction alerts! Redirecting to review...'),
              backgroundColor: Colors.teal,
            ),
          );
          context.push('/transactions/review', extra: parsedTxs);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Scanned Gmail box. No new matching transaction alerts found in the last 30 days.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync Failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
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

  Future<void> _addSenderDomain() async {
    final controller = TextEditingController();
    final domain = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bank Sender'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter the exact notification email of your bank (e.g. transactionalerts@bank.com)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Sender Email Address',
                hintText: 'alerts@hdfcbank.net',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (domain != null && domain.isNotEmpty) {
      if (_senderDomains.contains(domain)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This sender email is already in the scan list.')),
        );
        return;
      }
      setState(() {
        _senderDomains.add(domain);
      });
      await DatabaseService.settingsBox.put('gmail_sender_domains', _senderDomains);
    }
  }

  Future<void> _removeSenderDomain(String domain) async {
    setState(() {
      _senderDomains.remove(domain);
    });
    await DatabaseService.settingsBox.put('gmail_sender_domains', _senderDomains);
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.shield_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            const Text('Gmail Privacy Policy'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Our Privacy & Transparency Commitment',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 12),
              BulletItem(text: 'Local-First Analysis: Scanned email bodies are processed on-device and in-memory only. Full message text is never logged, saved, or uploaded.'),
              BulletItem(text: 'Read-Only Scope: We strictly authorize the narrowest `gmail.readonly` permission scope to run regex alert parsing. No send or write access is granted.'),
              BulletItem(text: 'Strict Filter Rule: Only emails matching your configured list of sender domains will be examined. Private mail is entirely ignored.'),
              BulletItem(text: 'Full Control: Disconnecting revokes the login session, deletes cache lists, and removes all synchronization metadata from local app storage.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I Agree'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = _googleUser != null;
    final syncStatus = ref.watch(syncStatusProvider);
    final syncMessage = ref.watch(syncStatusMessageProvider);
    final autoSyncService = ref.read(autoSyncServiceProvider);

    final formattedLastSync = _lastSyncTime != null
        ? DateFormat('MMM dd, yyyy  •  hh:mm a').format(DateTime.parse(_lastSyncTime!))
        : 'Never Synchronized';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gmail Sync Center'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Banner Card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.primaryContainer.withAlpha(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.primary.withAlpha(45)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.email_outlined, size: 28, color: Colors.redAccent),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gmail Financial Sync',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Import bank notifications dynamically into your register on demand, locally and in-memory.',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),                // Connection status section
                _buildSectionHeader(isConnected ? 'Google Account' : 'Sync Engine Status'),
                if (!isConnected) ...[
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
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
                                      'Requires authenticated login to check emails',
                                      style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                    onPressed: _isLoading ? null : _connectGmail,
                    icon: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.login_rounded),
                    label: const Text('Connect Gmail Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ] else ...[
                  Card(
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
                              // Auto-sync: On green badge
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
                              // Subtle animated sync icon when actively syncing, fallback to standard clock
                              syncStatus == SyncStatus.syncing
                                  ? const AnimatedSyncIcon()
                                  : Icon(Icons.cloud_done, color: theme.colorScheme.outline, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // "Last synced: [relative time]" — use timeago formatting (e.g. "3 minutes ago")
                                    Text(
                                      _formatTimeAgo(autoSyncService.lastSyncedAt),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    // "Transactions backed up: [N]"
                                    Text(
                                      "Transactions synchronized: ${_transactionsBackedUp ?? _lastSyncCount ?? 0}",
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurfaceVariant,
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
                              // "Sync now" text button
                              TextButton.icon(
                                onPressed: (syncStatus == SyncStatus.syncing || _isSyncing)
                                    ? null
                                    : () async {
                                        await ref.read(autoSyncServiceProvider).syncNow();
                                        // Refresh backup count
                                        final user = GmailSyncService.currentUser;
                                        if (user != null) {
                                          final backupInfo = await FirebaseBackupService.checkBackupExists(user.email);
                                          if (mounted) {
                                            setState(() {
                                              _transactionsBackedUp = backupInfo?.transactionCount ?? 0;
                                            });
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.sync, size: 16),
                                label: const Text('Sync now'),
                              ),
                              const SizedBox(width: 8),
                              // "Disconnect" button (destructive, with confirmation dialog)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.error,
                                ),
                                onPressed: _isLoading ? null : _disconnectGmail,
                                icon: const Icon(Icons.power_settings_new, size: 16),
                                label: const Text('Disconnect'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Sender Configuration Column
                _buildSectionHeader('Configured Bank alert Senders'),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Only emails from these specific senders are scanned for transaction layouts:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            ..._senderDomains.map((domain) {
                              return InputChip(
                                label: Text(domain, style: const TextStyle(fontSize: 11)),
                                onDeleted: () => _removeSenderDomain(domain),
                                deleteIcon: const Icon(Icons.cancel, size: 14),
                              );
                            }),
                            ActionChip(
                              backgroundColor: theme.colorScheme.primary.withAlpha(20),
                              avatar: Icon(Icons.add, size: 14, color: theme.colorScheme.primary),
                              label: Text('Add Sender', style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: _addSenderDomain,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Scanned Emails Logs Section
                _buildSectionHeader('Scanned email record registry'),
                if (_scannedEmails.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.mark_email_read, size: 40, color: theme.colorScheme.outline.withAlpha(100)),
                          const SizedBox(height: 10),
                          const Text(
                            'No scan history found on-device.\nAuthorize and press Sync to begin scan.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _scannedEmails.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final log = _scannedEmails[index];
                        final logDate = log['date'] ?? '';
                        final logFrom = log['sender'] ?? '';
                        final logSubject = log['subject'] ?? '';
                        final logResult = log['parsedResult'] ?? '';

                        final isMatchedFlag = logResult.contains('Matched');

                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isMatchedFlag ? Icons.check_circle : Icons.mail,
                            color: isMatchedFlag ? Colors.teal : theme.colorScheme.outline,
                            size: 18,
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  logFrom,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                logDate,
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(logSubject, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                              const SizedBox(height: 2),
                              Text(
                                logResult,
                                style: TextStyle(
                                  fontWeight: isMatchedFlag ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 10.5,
                                  color: isMatchedFlag ? Colors.teal : theme.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 36),

                // Privacy Commitment Statement link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _showPrivacyPolicy,
                      child: Text(
                        'Read our secure on-device Privacy Promise',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
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
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          letterSpacing: 1.1,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSyncStatusIcon(SyncStatus status, ThemeData theme) {
    switch (status) {
      case SyncStatus.syncing:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SyncStatus.success:
        return const Icon(Icons.check_circle_rounded, color: Colors.teal, size: 20);
      case SyncStatus.error:
        return Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 20);
      case SyncStatus.idle:
      default:
        return Icon(Icons.cloud_done_outlined, color: theme.colorScheme.outline, size: 20);
    }
  }

  String _getSyncStatusText(SyncStatus status, String? message, DateTime? lastSynced) {
    switch (status) {
      case SyncStatus.syncing:
        return "Syncing...";
      case SyncStatus.error:
        return "Sync failed";
      case SyncStatus.success:
      case SyncStatus.idle:
      default:
        if (lastSynced == null) return "Never synced";
        return _formatTimeAgo(lastSynced);
    }
  }

  Color _getSyncStatusColor(SyncStatus status, ThemeData theme) {
    switch (status) {
      case SyncStatus.syncing:
        return theme.colorScheme.primary;
      case SyncStatus.success:
        return Colors.teal;
      case SyncStatus.error:
        return theme.colorScheme.error;
      case SyncStatus.idle:
      default:
        return theme.colorScheme.onSurface;
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
}

class BulletItem extends StatelessWidget {
  final String text;
  const BulletItem({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedSyncIcon extends StatefulWidget {
  const AnimatedSyncIcon({super.key});

  @override
  _AnimatedSyncIconState createState() => _AnimatedSyncIconState();
}

class _AnimatedSyncIconState extends State<AnimatedSyncIcon> with SingleTickerProviderStateMixin {
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
