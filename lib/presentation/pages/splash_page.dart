import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_app/presentation/providers/repository_providers.dart';
import 'package:tracker_app/core/services/gmail_sync_service.dart';
import 'package:tracker_app/data/services/database_service.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Show splash for at least 1.5 seconds for visual feedback
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final result = await ref.read(settingsRepositoryProvider).getSettings();
    final isLocked = result.fold((_) => false, (s) => s.isBiometricEnabled);

    if (isLocked) {
      if (mounted) context.go('/auth');
      return;
    }

    final firstRun = DatabaseService.settingsBox.get('first_run') as bool?;

    if (firstRun == null) {
      // Reinstall detection: local boxes empty but user is already signed in to Google
      final silentUser = await GmailSyncService.getConnectedAccount();
      if (silentUser != null) {
        await DatabaseService.settingsBox.put('first_run', false);
        if (mounted) context.go('/dashboard', extra: 'auto_restore');
        return;
      }
      
      if (mounted) context.go('/onboarding');
      return;
    }

    if (mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Transaction tracker',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
