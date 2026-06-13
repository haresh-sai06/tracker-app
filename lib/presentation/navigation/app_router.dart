import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tracker_app/presentation/pages/splash_page.dart';
import 'package:tracker_app/presentation/pages/dashboard_page.dart';
import 'package:tracker_app/presentation/pages/transactions_page.dart';
import 'package:tracker_app/presentation/pages/add_transaction_page.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/presentation/pages/transaction_detail_page.dart';
import 'package:tracker_app/presentation/pages/accounts_page.dart';
import 'package:tracker_app/presentation/pages/account_detail_page.dart';
import 'package:tracker_app/presentation/pages/add_edit_account_page.dart';
import 'package:tracker_app/domain/entities/account.dart';
import 'package:tracker_app/presentation/pages/insights_page.dart';
import 'package:tracker_app/presentation/pages/settings_page.dart';
import 'package:tracker_app/presentation/pages/privacy_policy_page.dart';
import 'package:tracker_app/presentation/pages/export_page.dart';
import 'package:tracker_app/presentation/pages/gmail_sync_page.dart';
import 'package:tracker_app/presentation/pages/onboarding_page.dart';
import 'package:tracker_app/presentation/pages/auth_page.dart';
import 'package:tracker_app/presentation/pages/categories_page.dart';
import 'package:tracker_app/presentation/pages/add_category_page.dart';
import 'package:tracker_app/domain/entities/category.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_app/presentation/providers/auth_provider.dart';
import 'package:tracker_app/presentation/providers/repository_providers.dart';
import 'package:tracker_app/presentation/pages/sms_permission_page.dart';
import 'package:tracker_app/presentation/pages/parsed_transaction_review_page.dart';
import 'package:tracker_app/core/services/sms_parser_service.dart';
import 'package:tracker_app/core/services/sms_listener_service.dart';
import 'package:tracker_app/core/services/notification_listener_service.dart';
import 'package:tracker_app/presentation/providers/permissions_provider.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesPage(),
      ),
      GoRoute(
        path: '/categories/add',
        builder: (context, state) {
          final cat = state.extra as Category?;
          return AddCategoryPage(initialCategory: cat);
        },
      ),
      GoRoute(
        path: '/permissions/sms',
        builder: (context, state) {
          return SmsPermissionPage(
            onComplete: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          );
        },
      ),
      GoRoute(
        path: '/transactions/review',
        builder: (context, state) {
          if (state.extra is List<ParsedTransaction>) {
            final parsedTxs = state.extra as List<ParsedTransaction>;
            return ParsedTransactionReviewPage(parsedTxs: parsedTxs);
          } else {
            final parsedTx = state.extra as ParsedTransaction;
            return ParsedTransactionReviewPage(parsedTx: parsedTx);
          }
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) => const TransactionsPage(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) {
                      final tx = state.extra as Transaction?;
                      return AddTransactionPage(initialTransaction: tx);
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return TransactionDetailPage(id: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/accounts',
                builder: (context, state) => const AccountsPage(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) {
                      final account = state.extra as Account?;
                      return AddEditAccountPage(initialAccount: account);
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return AccountDetailPage(id: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/insights',
                builder: (context, state) => const InsightsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
                routes: [
                  GoRoute(
                    path: 'export',
                    builder: (context, state) => const ExportPage(),
                  ),
                  GoRoute(
                    path: 'gmail',
                    builder: (context, state) => const GmailSyncPage(),
                  ),
                  GoRoute(
                    path: 'privacy',
                    builder: (context, state) => const PrivacyPolicyPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize SMS and Notification listener services
    ref.read(smsListenerServiceProvider).initialize(context);
    ref.read(notificationListenerServiceProvider).initialize(context);

    // Import any pending background transactions on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SmsListenerService.checkAndImportPendingTransactions(ref, context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      ref.read(authNotifierProvider.notifier).lock();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(permissionsNotifierProvider.notifier).refresh();
      
      // Import any pending background transactions on resume
      SmsListenerService.checkAndImportPendingTransactions(ref, context);

      final settingsResult = await ref.read(settingsRepositoryProvider).getSettings();
      settingsResult.fold(
        (_) {},
        (settings) {
          final isLocked = ref.read(authNotifierProvider).valueOrNull?.isLocked ?? false;
          if (settings.isBiometricEnabled && isLocked) {
            final router = GoRouter.of(context);
            final currentPath = router.routerDelegate.currentConfiguration.uri.path;
            if (currentPath != '/auth') {
              context.push('/auth');
            }
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance),
            label: 'Accounts',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
