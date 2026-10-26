import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/entities/category.dart';
import 'package:tracker_app/presentation/providers/categories_provider.dart';
import 'package:tracker_app/presentation/providers/settings_provider.dart';
import 'package:tracker_app/presentation/providers/dashboard_provider.dart';
import 'package:tracker_app/presentation/providers/permissions_provider.dart';
import 'package:tracker_app/core/services/app_health_service.dart';
import 'package:tracker_app/presentation/providers/wallets_provider.dart';
import 'package:tracker_app/core/utils/currency_utils.dart';
import 'package:tracker_app/presentation/widgets/currency_selector_sheet.dart';
import 'package:tracker_app/presentation/widgets/panel_entrance.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:tracker_app/core/services/gmail_sync_service.dart';
import 'package:tracker_app/core/services/firebase_backup_service.dart';
import 'package:tracker_app/core/services/auto_sync_service.dart';
import 'package:tracker_app/data/services/database_service.dart';
import 'package:tracker_app/presentation/providers/accounts_provider.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _isSpeedDialOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForCloudRestoreAndConflicts();
    });
  }

  Future<void> _checkForCloudRestoreAndConflicts() async {
    final user = GmailSyncService.currentUser ?? await GmailSyncService.getConnectedAccount();
    if (user == null) return;

    final localTxCount = DatabaseService.transactionsBox.values.where((tx) => !(tx.isDeleted ?? false)).length;
    final transactionsEmpty = DatabaseService.transactionsBox.isEmpty;

    if (transactionsEmpty) {
      // Trigger automatic silent restore (reinstall detection case)
      _performAutoRestore(user.email);
      return;
    }

    try {
      final backupInfo = await FirebaseBackupService.checkBackupExists(user.email);
      if (backupInfo == null) return;

      final cloudTxCount = backupInfo.transactionCount;
      final diff = (localTxCount - cloudTxCount).abs();

      if (diff > 5) {
        // Data conflict detected!
        _showConflictDialog(user.email, localTxCount, cloudTxCount, backupInfo.timestamp);
      }
    } catch (e) {
      debugPrint("Conflict check failed: $e");
    }
  }

  Future<void> _performAutoRestore(String email) async {
    try {
      ref.read(isRestoringProvider.notifier).state = true;
      ref.read(restoreProgressCountProvider.notifier).state = null;
      ref.read(restoreMessageProvider.notifier).state = "Welcome back! Syncing Google account...";

      final backupInfo = await FirebaseBackupService.checkBackupExists(email);
      if (backupInfo == null) {
        ref.read(isRestoringProvider.notifier).state = false;
        return;
      }

      final txCount = backupInfo.transactionCount;
      ref.read(restoreProgressCountProvider.notifier).state = txCount;
      ref.read(restoreMessageProvider.notifier).state = "Welcome back! Synchronizing $txCount transactions...";

      final success = await FirebaseBackupService.performRestore(email);

      if (success) {
        final newLocalTxCount = DatabaseService.transactionsBox.values.where((tx) => !(tx.isDeleted ?? false)).length;
        
        ref.invalidate(accountsNotifierProvider);
        ref.invalidate(transactionsNotifierProvider);
        ref.invalidate(categoriesNotifierProvider);
        ref.invalidate(settingsNotifierProvider);
        
        await ref.read(dashboardNotifierProvider.notifier).refresh();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Synchronized successfully. $newLocalTxCount transactions loaded."),
              backgroundColor: Colors.teal,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Auto synchronization failed. Please try again from settings."),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Auto restore error: $e");
    } finally {
      ref.read(isRestoringProvider.notifier).state = false;
    }
  }

  Future<void> _showConflictDialog(
      String email, int localCount, int cloudCount, DateTime cloudTime) async {
    DateTime? localLastModified;
    final allTxs = DatabaseService.transactionsBox.values.toList();
    for (final tx in allTxs) {
      if (tx.updatedAt != null) {
        if (localLastModified == null || tx.updatedAt!.isAfter(localLastModified)) {
          localLastModified = tx.updatedAt;
        }
      }
    }
    localLastModified ??= DateTime.now();

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final localTimeStr = dateFormat.format(localLastModified);
    final cloudTimeStr = dateFormat.format(cloudTime);

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text("Synchronization mismatch detected"),
            content: Text(
              "Local: $localCount transactions, last modified $localTimeStr.\n\n"
              "Server: $cloudCount transactions, matched $cloudTimeStr.\n\n"
              "Which should be kept?"
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  _resolveConflictKeepLocal(email);
                },
                child: const Text("Keep local"),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  _resolveConflictKeepCloud(email);
                },
                child: const Text("Keep server"),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _resolveConflictKeepLocal(String email) async {
    setState(() {
      _isSpeedDialOpen = false;
    });
    ref.read(isRestoringProvider.notifier).state = true;
    ref.read(restoreProgressCountProvider.notifier).state = null;
    ref.read(restoreMessageProvider.notifier).state = "Uploading local data to account server...";

    try {
      final success = await FirebaseBackupService.performBackup(email);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account database synchronized with your local data."), backgroundColor: Colors.teal),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to synchronize local data."), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      debugPrint("Keep local resolve error: $e");
    } finally {
      ref.read(isRestoringProvider.notifier).state = false;
    }
  }

  Future<void> _resolveConflictKeepCloud(String email) async {
    ref.read(isRestoringProvider.notifier).state = true;
    ref.read(restoreProgressCountProvider.notifier).state = null;
    ref.read(restoreMessageProvider.notifier).state = "Downloading synchronized data...";

    try {
      final success = await FirebaseBackupService.performRestore(email);
      if (success) {
        ref.invalidate(accountsNotifierProvider);
        ref.invalidate(transactionsNotifierProvider);
        ref.invalidate(categoriesNotifierProvider);
        ref.invalidate(settingsNotifierProvider);

        await ref.read(dashboardNotifierProvider.notifier).refresh();

        final newLocalTxCount = DatabaseService.transactionsBox.values.where((tx) => !(tx.isDeleted ?? false)).length;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Synchronized successfully. $newLocalTxCount transactions loaded."), backgroundColor: Colors.teal),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to download account synchronized data."), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      debugPrint("Keep cloud resolve error: $e");
    } finally {
      ref.read(isRestoringProvider.notifier).state = false;
    }
  }

  void _navigateAddTransaction(TransactionType type) {
    final now = DateTime.now();
    final shellTx = Transaction(
      id: '', // empty ID to indicate a new transaction
      amount: 0.0,
      type: type,
      category: '',
      accountId: '',
      description: '',
      source: TransactionSource.manual,
      dateTime: now,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    );
    context.push('/transactions/add', extra: shellTx);
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardNotifierProvider);
    final categoriesAsync = ref.watch(categoriesNotifierProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final permissionsAsync = ref.watch(permissionsNotifierProvider);
    final dismissedIssues = ref.watch(dismissedHealthIssuesProvider);

    final categories = categoriesAsync.valueOrNull ?? [];
    final appSettings = settingsAsync.valueOrNull;
    final activeWallet = ref.watch(activeWalletProvider);
    final currencyCode = activeWallet.currencyCode;
    final currencySymbol = CurrencyUtils.symbolFor(currencyCode);

    List<HealthIssue> healthIssues = [];
    if (appSettings != null && permissionsAsync.hasValue) {
      final permissions = permissionsAsync.value;
      if (permissions != null) {
        healthIssues = AppHealthService.checkHealth(
          settings: appSettings,
          permissions: permissions,
          context: context,
          ref: ref,
        ).where((issue) => !dismissedIssues.contains(issue.feature)).toList();
      }
    }

    final isRestoring = ref.watch(isRestoringProvider);
    final restoreMessage = ref.watch(restoreMessageProvider);
    final restoreProgressCount = ref.watch(restoreProgressCountProvider);

    return Scaffold(
      floatingActionButton: _buildFAB(context),
      body: SafeArea(
        child: Stack(
          children: [
            dashboardAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => ref.read(dashboardNotifierProvider.notifier).refresh(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (state) {
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.read(permissionsNotifierProvider.notifier).refresh();
                    await ref.read(dashboardNotifierProvider.notifier).refresh();
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // 0. App Health Banner
                      if (healthIssues.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _buildHealthBanner(context, healthIssues),
                        ),

                      // 1. Greeting header & avatar
                      SliverToBoxAdapter(
                        child: _buildGreetingHeader(context, state.selectedPeriod, ref.watch(settingsNotifierProvider).valueOrNull?.userName),
                      ),
                      
                       // 2. Period Selector Chips
                      SliverToBoxAdapter(
                        child: _buildPeriodSelector(context, state.selectedPeriod),
                      ),

                      if (state.recentTransactions.isEmpty) ...[
                        // Specifc zero-transactions empty State for active wallet
                        SliverToBoxAdapter(
                          child: PanelEntrance(
                            child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.outlineVariant,
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_outlined,
                                      size: 64,
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No data in $currencyCode yet.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add a transaction or switch wallet.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        showCurrencySelector(context);
                                      },
                                      icon: const Icon(Icons.swap_horiz),
                                      label: const Text('Switch Wallet'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          ),
                        ),
                      ] else ...[
                        // 3. Net Worth & Account Balances PageView
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: SizedBox(
                              height: 190,
                              child: PageView.builder(
                                controller: PageController(viewportFraction: 0.92),
                                itemCount: state.accountBalances.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                      child: _buildNetWorthCard(
                                        context, 
                                        state.totalNetWorth, 
                                        currencySymbol, 
                                        currencyCode,
                                        'TOTAL NET WORTH',
                                        'Aggregated balance across all active accounts'
                                      ),
                                    );
                                  } else {
                                    final accInfo = state.accountBalances[index - 1];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                      child: _buildNetWorthCard(
                                        context, 
                                        accInfo.balance, 
                                        currencySymbol, 
                                        currencyCode,
                                        accInfo.account.name.toUpperCase(),
                                        accInfo.account.bankName ?? 'Bank Account'
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ),

                        // 4. Summary cards row
                        SliverToBoxAdapter(
                          child: PanelEntrance(
                            child: _buildSummaryCardsRow(context, state.summary, currencySymbol),
                          ),
                        ),

                        // 5. Recent Transactions section header & Link
                        SliverToBoxAdapter(
                          child: _buildRecentTransactionsHeader(context),
                        ),

                        // 6. Last 5 Transactions list
                        _buildRecentTransactionsList(
                          context,
                          state.recentTransactions,
                          categories,
                          currencySymbol,
                        ),
                      ],

                      // Padding spacer at the bottom so elements are not covered by the FAB
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 80),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (isRestoring)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Card(
                  elevation: 6,
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                restoreProgressCount != null
                                    ? "Restoring $restoreProgressCount transactions..."
                                    : restoreMessage,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingHeader(BuildContext context, DateTime selectedPeriod, String? customName) {
    final hour = DateTime.now().hour;
    String greetingText;
    if (hour < 12) {
      greetingText = 'Good morning';
    } else if (hour < 17) {
      greetingText = 'Good afternoon';
    } else {
      greetingText = 'Good evening';
    }

    final now = DateTime.now();
    final dateStr = DateFormat('MMMM d, yyyy').format(now);

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greetingText,',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 0.2,
                      ),
                ),
                StreamBuilder(
                  stream: GmailSyncService.googleSignIn.onCurrentUserChanged,
                  initialData: GmailSyncService.currentUser,
                  builder: (context, snapshot) {
                    final userName = customName != null && customName.isNotEmpty 
                        ? customName 
                        : snapshot.data?.displayName;
                    if (userName == null || userName.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        userName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              context.push('/settings');
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: StreamBuilder(
                stream: GmailSyncService.googleSignIn.onCurrentUserChanged,
                initialData: GmailSyncService.currentUser,
                builder: (context, snapshot) {
                  final photoUrl = snapshot.data?.photoUrl;
                  return CircleAvatar(
                    radius: 22,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null 
                        ? Icon(
                            Icons.person,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ) 
                        : null,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context, DateTime selectedPeriod) {
    final now = DateTime.now();
    final lastMonthVal = DateTime(now.year, now.month - 1, 1);

    final isThisMonth = selectedPeriod.year == now.year && selectedPeriod.month == now.month;
    final isLastMonth = selectedPeriod.year == lastMonthVal.year && selectedPeriod.month == lastMonthVal.month;
    final isCustom = !isThisMonth && !isLastMonth;

    final customLabel = isCustom ? DateFormat('MMMM yyyy').format(selectedPeriod) : 'Custom';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('This Month'),
              selected: isThisMonth,
              onSelected: (selected) {
                if (selected) {
                  ref.read(dashboardNotifierProvider.notifier).changePeriod(now);
                }
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Last Month'),
              selected: isLastMonth,
              onSelected: (selected) {
                if (selected) {
                  ref.read(dashboardNotifierProvider.notifier).changePeriod(lastMonthVal);
                }
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(customLabel),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
              selected: isCustom,
              onSelected: (selected) async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedPeriod,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  helpText: 'Select Month',
                );
                if (picked != null) {
                  ref.read(dashboardNotifierProvider.notifier).changePeriod(picked);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetWorthCard(BuildContext context, double totalNetWorth, String currencySymbol, String currencyCode, String title, String subtitle) {
    final isNeg = totalNetWorth < 0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primaryContainer.withAlpha(200),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withAlpha(40),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary.withAlpha(200),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
              ),
              Icon(
                Icons.account_balance_wallet,
                color: Theme.of(context).colorScheme.onPrimary.withAlpha(200),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${isNeg ? '-' : ''}$currencySymbol${totalNetWorth.abs().toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  showCurrencySelector(context);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currencyCode,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary.withAlpha(180),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCardsRow(BuildContext context, dynamic summary, String currencySymbol) {
    const posColor = Color(0xFF2E7D32);
    const negColor = Color(0xFFC62828);
    final neutralColor = Theme.of(context).colorScheme.primary;

    final isNetPos = summary.netChange > 0;
    final isNetNeg = summary.netChange < 0;
    final netColor = isNetPos ? posColor : (isNetNeg ? negColor : neutralColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItemCard(
              context: context,
              title: 'Income',
              amount: summary.totalCredits,
              amountColor: posColor,
              icon: Icons.arrow_upward,
              iconColor: Colors.green,
              currencySymbol: currencySymbol,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryItemCard(
              context: context,
              title: 'Expense',
              amount: summary.totalDebits,
              amountColor: negColor,
              icon: Icons.arrow_downward,
              iconColor: Colors.redAccent,
              currencySymbol: currencySymbol,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryItemCard(
              context: context,
              title: 'Net',
              amount: summary.netChange,
              amountColor: netColor,
              icon: Icons.swap_horiz,
              iconColor: Colors.blueAccent,
              currencySymbol: currencySymbol,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItemCard({
    required BuildContext context,
    required String title,
    required double amount,
    required Color amountColor,
    required IconData icon,
    required Color iconColor,
    required String currencySymbol,
  }) {
    final isNeg = amount < 0;
    final displayAmount = amount.abs();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(60),
        ),
      ),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${isNeg ? '-' : ''}$currencySymbol${displayAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0, bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Recent Transactions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          TextButton(
            onPressed: () {
              context.go('/transactions');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'See All',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 11,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsList(
    BuildContext context,
    List<Transaction> recentTransactions,
    List<Category> categories,
    String currencySymbol,
  ) {
    if (recentTransactions.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline.withAlpha(120),
              ),
              const SizedBox(height: 12),
              Text(
                'No transactions found',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final tiles = <Widget>[];
    for (final tx in recentTransactions) {
      final isDebit = tx.type == TransactionType.debit;

      final category = categories.firstWhere(
        (c) => c.id == tx.category,
        orElse: () => const Category(
          id: 'unknown',
          name: 'Unknown',
          iconCodePoint: 57935,
          colorValue: 0xFF607D8B,
          isDefault: false,
          isDeleted: false,
        ),
      );

      tiles.add(
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withAlpha(65),
                ),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: ListTile(
                onTap: () => context.push('/transactions/${tx.id}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: Color(category.colorValue).withAlpha(35),
                  radius: 20,
                  child: Icon(
                    IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'),
                    color: Color(category.colorValue),
                    size: 20,
                  ),
                ),
                title: Text(
                  tx.merchantName ?? (tx.description.isNotEmpty ? tx.description : category.name),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _getSourceLabel(tx.source),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.primary.withAlpha(180),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isDebit ? '-' : '+'}$currencySymbol${tx.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDebit ? Colors.redAccent : Colors.green,
                      ),
                    ),
                    Text(
                      isDebit ? 'Debit' : 'Credit',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      );
    }

    return SliverToBoxAdapter(
      child: PanelEntrance(
        child: Column(
          children: tiles,
        ),
      ),
    );
  }

  String _getSourceLabel(TransactionSource source) {
    switch (source) {
      case TransactionSource.sms:
        return 'SMS';
      case TransactionSource.notification:
        return 'Alert';
      case TransactionSource.email:
        return 'Gmail';
      case TransactionSource.manual:
      default:
        return 'Manual';
    }
  }

  Widget _buildFAB(BuildContext context) {
    if (!_isSpeedDialOpen) {
      return FloatingActionButton(
        key: const ValueKey('main_fab_closed'),
        onPressed: () {
          setState(() {
            _isSpeedDialOpen = true;
          });
        },
        child: const Icon(Icons.add),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              elevation: 3,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                child: Text(
                  'Add Income',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              heroTag: 'income_fab',
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              onPressed: () {
                setState(() {
                  _isSpeedDialOpen = false;
                });
                _navigateAddTransaction(TransactionType.credit);
              },
              child: const Icon(Icons.arrow_upward),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              elevation: 3,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                child: Text(
                  'Add Expense',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              heroTag: 'expense_fab',
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              onPressed: () {
                setState(() {
                  _isSpeedDialOpen = false;
                });
                _navigateAddTransaction(TransactionType.debit);
              },
              child: const Icon(Icons.arrow_downward),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          key: const ValueKey('main_fab_open'),
          onPressed: () {
            setState(() {
              _isSpeedDialOpen = false;
            });
          },
          child: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildHealthBanner(BuildContext context, List<HealthIssue> issues) {
    if (issues.isEmpty) return const SizedBox.shrink();
    
    final issue = issues.first; // Show first active issue
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 4.0),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: theme.colorScheme.errorContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.error.withOpacity(0.3)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: issue.action,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.onErrorContainer,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Access Alert: ${issue.feature}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        issue.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer.withOpacity(0.9),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${issue.actionLabel.toUpperCase()} →',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onErrorContainer,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.onErrorContainer.withOpacity(0.7),
                  ),
                  onPressed: () {
                    ref.read(dismissedHealthIssuesProvider.notifier).update(
                          (state) => {...state, issue.feature},
                        );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
