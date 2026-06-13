import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tracker_app/core/services/gmail_sync_service.dart';
import 'package:tracker_app/core/services/firebase_backup_service.dart';
import 'package:tracker_app/data/services/database_service.dart';
import 'package:tracker_app/presentation/providers/settings_provider.dart';
import 'package:tracker_app/presentation/providers/accounts_provider.dart';
import 'package:tracker_app/presentation/providers/categories_provider.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  bool _isLoading = false;
  String? _loadingMessage;

  Future<void> _continueWithoutAccount() async {
    await DatabaseService.settingsBox.put('first_run', false);
    if (mounted) {
      context.go('/dashboard');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = "Syncing Google Account...";
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

      // Check if backup exists
      final backupInfo = await FirebaseBackupService.checkBackupExists(user.email);

      if (mounted) {
        if (backupInfo != null) {
          // Backup found. Show non-dismissible dialog
          final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(backupInfo.timestamp);
          final restoreNow = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return PopScope(
                canPop: false,
                child: AlertDialog(
                  title: const Text('Saved data found'),
                  content: Text('A saved footprint from $formattedDate was found with ${backupInfo.transactionCount} transactions. Synchronize and restore it now?'),
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
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

              await DatabaseService.settingsBox.put('first_run', false);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Successfully synchronized and recovered all your data!'), backgroundColor: Colors.teal),
                );
                context.go('/dashboard');
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to synchronize data. Proceeding with empty database.'), backgroundColor: Colors.orangeAccent),
                );
                await _startFreshFlow(user.email);
              }
            }
          } else {
            // "Start fresh" chosen
            await _startFreshFlow(user.email);
          }
        } else {
          // No backup exists
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signed in. Your data will be backed up automatically.'), backgroundColor: Colors.teal),
          );
          await _startFreshFlow(user.email);
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

  Future<void> _startFreshFlow(String email) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = "Initializing fresh profile...";
    });
    await ref.read(settingsNotifierProvider.notifier).clearAllData();
    // Start sync (creating initial document)
    await FirebaseBackupService.performBackup(email);
    await DatabaseService.settingsBox.put('first_run', false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Started fresh. Empty database initialized and synced.'), backgroundColor: Colors.teal),
      );
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 84,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Transaction tracker',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Take control of your personal finances with secure local storage and seamless Google account synchronization.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.cloud_done_rounded),
                    label: const Text(
                      'Sign in with Google',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _continueWithoutAccount,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.colorScheme.outline),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text(
                      'Continue without account',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ],
              ),
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
}
