import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_app/data/services/database_service.dart';
import 'package:tracker_app/presentation/navigation/app_router.dart';
import 'package:tracker_app/presentation/providers/repository_providers.dart';
import 'package:tracker_app/data/repositories/transaction_repository_impl.dart';
import 'package:tracker_app/data/repositories/category_repository_impl.dart';
import 'package:tracker_app/data/repositories/account_repository_impl.dart';
import 'package:tracker_app/data/repositories/settings_repository_impl.dart';

import 'package:tracker_app/presentation/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.initialize();
  
  // Custom ErrorWidget builder for high-quality fallback and release hardening
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) {
      // In debug mode, show the normal Flutter red/yellow exception screen to help developers
      return ErrorWidget(details.exception);
    }
    // In release/profile mode, show a highly polished, clean Material 3 design card fallback
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Something went wrong',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'An unexpected system glitch occurred. No worries - all your transactional data is safely stored on-device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Restart the app navigation route back home
                        // or simple retry setup
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reload Interface'),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  };
  
  runApp(
    ProviderScope(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(TransactionRepositoryImpl()),
        categoryRepositoryProvider.overrideWithValue(CategoryRepositoryImpl()),
        accountRepositoryProvider.overrideWithValue(AccountRepositoryImpl()),
        settingsRepositoryProvider.overrideWithValue(SettingsRepositoryImpl()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final themeString = settingsAsync.valueOrNull?.themeMode ?? 'system';
    final themeMode = switch (themeString) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return MaterialApp.router(
      title: 'Transaction Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
