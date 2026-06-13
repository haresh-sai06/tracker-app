import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tracker_app/domain/entities/app_settings.dart';
import 'package:tracker_app/domain/entities/account.dart';
import 'package:tracker_app/presentation/providers/settings_provider.dart';
import 'package:tracker_app/presentation/providers/accounts_provider.dart';
import 'package:tracker_app/presentation/providers/auth_provider.dart';
import 'package:tracker_app/core/services/sms_listener_service.dart';
import 'package:tracker_app/core/services/notification_listener_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tracker_app/core/services/gmail_sync_service.dart';
import 'package:tracker_app/presentation/widgets/settings/google_sync_card.dart';
import 'package:tracker_app/domain/entities/currency_wallet.dart';
import 'package:tracker_app/presentation/providers/wallets_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with WidgetsBindingObserver {
  bool _isNotificationPermissionGranted = false;
  String _appVersion = '1.0.0';

  final Map<String, String> _commonCurrencies = {
    'USD': '\$ (US Dollar)',
    'EUR': '€ (Euro)',
    'INR': '₹ (Indian Rupee)',
    'GBP': '£ (British Pound)',
    'JPY': '¥ (Japanese Yen)',
    'AUD': 'A\$ (Australian Dollar)',
    'CAD': 'C\$ (Canadian Dollar)',
    'CNY': '¥ (Chinese Yuan)',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNotificationPermission();
    _loadAppVersion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationPermission();
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {}
  }

  Future<void> _checkNotificationPermission() async {
    final granted = await NotificationListenerService.isPermissionGranted();
    if (mounted) {
      setState(() {
        _isNotificationPermissionGranted = granted;
      });
    }
  }

  Future<void> _showAccountSelectorDialog(AppSettings settings) async {
    final accountsAsyncValue = ref.read(accountsNotifierProvider);
    final accounts = (accountsAsyncValue.valueOrNull ?? [])
        .where((a) => !a.isDeleted)
        .toList();

    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No bank accounts found in register. Please add one first.')),
      );
      return;
    }

    final selectedId = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Default Account'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                final isSelected = account.id == settings.defaultAccountId;
                return ListTile(
                  leading: Icon(
                    account.type == AccountType.bank
                        ? Icons.account_balance_rounded
                        : account.type == AccountType.wallet
                            ? Icons.account_balance_wallet_rounded
                            : Icons.money_rounded,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(
                    account.name,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.teal)
                      : null,
                  onTap: () => Navigator.of(context).pop(account.id),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selectedId != null) {
      await ref
          .read(settingsNotifierProvider.notifier)
          .updateSetting('defaultAccountId', selectedId);
    }
  }

  Future<void> _showCurrencySelectorDialog(AppSettings settings) async {
    final selectedCode = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Display Currency'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _commonCurrencies.entries.map((entry) {
                final isSelected = entry.key == settings.defaultCurrencyCode;
                return ListTile(
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.teal)
                      : null,
                  onTap: () => Navigator.of(context).pop(entry.key),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selectedCode != null) {
      await ref
          .read(settingsNotifierProvider.notifier)
          .updateSetting('defaultCurrencyCode', selectedCode);
      // Also update the active wallet provider and invalidate relevant providers so UI updates immediately
      final walletsAsync = ref.read(walletListProvider);
      final wallets = walletsAsync.valueOrNull ?? [];
      final matchingWallet = wallets.firstWhere(
        (w) => w.currencyCode == selectedCode,
        orElse: () => CurrencyWallet(
          id: selectedCode,
          currencyCode: selectedCode,
          label: _commonCurrencies[selectedCode] ?? selectedCode,
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );
      await ref.read(walletListProvider.notifier).switchWallet(matchingWallet);
    }
  }

  // Method to ask for current PIN via custom Dialog to disable lock
  Future<String?> _showPinConfirmationDialog() async {
    String pin = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.lock_person, color: Colors.blueAccent),
                  SizedBox(width: 8),
                  Text('Verify security PIN'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Please re-enter your 6-digit PIN to turn off biometric/PIN app lock.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      final isEntered = index < pin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isEntered
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isEntered
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  // Compact Custom NumPad inside Dialogue
                  _buildDialogNumPad(
                    onPress: (digit) {
                      if (pin.length < 6) {
                        setDialogState(() {
                          pin += digit;
                        });
                        if (pin.length == 6) {
                          Navigator.of(context).pop(pin);
                        }
                      }
                    },
                    onBackspace: () {
                      if (pin.isNotEmpty) {
                        setDialogState(() {
                          pin = pin.substring(0, pin.length - 1);
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDialogNumPad({
    required Function(String) onPress,
    required VoidCallback onBackspace,
  }) {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9']
        ]) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children:
                row.map((val) => _buildDialogNumButton(val, onPress)).toList(),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 50, height: 50),
            _buildDialogNumButton('0', onPress),
            SizedBox(
              width: 50,
              height: 50,
              child: IconButton(
                icon: const Icon(Icons.backspace_outlined, size: 20),
                onPressed: onBackspace,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDialogNumButton(String val, Function(String) onPress) {
    return SizedBox(
      width: 50,
      height: 50,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        onPressed: () => onPress(val),
        child: Text(
          val,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _showClearAllDataConfirmationDialog() async {
    final controller = TextEditingController();
    bool canDelete = false;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.warning_rounded, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  const Text('Clear All Data?'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'This action is permanent and cannot be undone!',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'All transactions, accounts, custom categories, and security lock settings will be deleted completely from this device.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Type DELETE to confirm:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'DELETE',
                      border: const OutlineInputBorder(),
                      errorText: (controller.text.isNotEmpty && !canDelete)
                          ? 'Input must match DELETE'
                          : null,
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        canDelete = val == 'DELETE';
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canDelete
                        ? theme.colorScheme.error
                        : theme.colorScheme.error.withOpacity(0.4),
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  onPressed:
                      canDelete ? () => Navigator.of(context).pop(true) : null,
                  child: const Text('Delete Everything'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Wiping local device database...',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      try {
        await ref.read(settingsNotifierProvider.notifier).clearAllData();

        setState(() {
          _isNotificationPermissionGranted = false;
        });

        if (mounted) {
          Navigator.of(context).pop(); // pop spinner
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'All local app registries have been successfully wiped clean.'),
              backgroundColor: Colors.teal,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // pop spinner
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear data: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.shield_outlined,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            const Text('Privacy Policy'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Our Absolute Privacy Promise',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 12),
              _BulletItem(
                  text:
                      'Local Storage Only: All finance transactions, bank account registry logs, and credentials remain 100% on sandboxed local Hive files on your physical device.'),
              _BulletItem(
                  text:
                      'No Backend Harvesting: We run zero analytical servers or remote cloud databases. Your transaction log is entirely your own private domain.'),
              _BulletItem(
                  text:
                      'Secure Sync Engines: Both SMS, notification listener, and Gmail reader access run on-device, parsing text streams in memory using local regex patterns. Safe and confidential.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeRadioGroup(AppSettings settings) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              const Text('Theme Mode Preference',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildThemeRadioOption('system', 'System', settings),
              _buildThemeRadioOption('light', 'Light', settings),
              _buildThemeRadioOption('dark', 'Dark', settings),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeRadioOption(
      String value, String label, AppSettings settings) {
    final isSelected = settings.themeMode == value;
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: () {
          ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('themeMode', value);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withAlpha(50)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withAlpha(100),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                value == 'system'
                    ? Icons.brightness_auto_rounded
                    : value == 'light'
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                size: 16,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, AppSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Profile'),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                StreamBuilder<GoogleSignInAccount?>(
                  stream: GmailSyncService.googleSignIn.onCurrentUserChanged,
                  initialData: GmailSyncService.currentUser,
                  builder: (context, snapshot) {
                    final photoUrl = snapshot.data?.photoUrl;
                    return CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null
                          ? Icon(Icons.person, size: 30, color: Theme.of(context).colorScheme.onPrimaryContainer)
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.userName ?? 'Add your name',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: settings.userName == null ? Colors.grey : null,
                            ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          final controller = TextEditingController(text: settings.userName);
                          final newName = await showDialog<String>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Edit Profile Name'),
                                content: TextField(
                                  controller: controller,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter your name',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(null),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(context).pop(controller.text),
                                    child: const Text('Save'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (newName != null && newName.trim().isNotEmpty) {
                            ref.read(settingsNotifierProvider.notifier).updateSetting('userName', newName.trim());
                          }
                        },
                        child: Text(
                          'Edit Profile Name',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsyncValue = ref.watch(settingsNotifierProvider);
    final accountsAsyncValue = ref.watch(accountsNotifierProvider);
    final accounts = accountsAsyncValue.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        elevation: 0,
      ),
      body: settingsAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (settings) {
          return ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            children: [
              // --- PROFILE SECTION ---
              _buildProfileSection(context, settings),

              // --- PREFERENCES SECTION ---
              _buildSectionHeader(context, 'Preferences'),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Column(
                  children: [
                    ListTile(
                      leading:
                          const Icon(Icons.account_balance_wallet_outlined),
                      title: const Text('Default Account',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        accounts
                            .firstWhere(
                                (a) => a.id == settings.defaultAccountId,
                                orElse: () =>
                                    accounts.firstOrNull ??
                                    const Account(
                                        id: '',
                                        name: 'No Accounts Specified',
                                        type: AccountType.bank,
                                        isDefault: false,
                                        isDeleted: false))
                            .name,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _showAccountSelectorDialog(settings),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.monetization_on_outlined),
                      title: const Text('Display Currency',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        _commonCurrencies[settings.defaultCurrencyCode] ??
                            settings.defaultCurrencyCode,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _showCurrencySelectorDialog(settings),
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildThemeRadioGroup(settings),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- SECURITY SECTION ---
              _buildSectionHeader(context, 'Security'),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('App Lock (PIN & Biometrics)',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: const Text(
                          'Ensure secure authentication on launch & resume'),
                      secondary: const Icon(Icons.security),
                      value: settings.isBiometricEnabled,
                      onChanged: (bool value) async {
                        if (value) {
                          // Direct to Auth Page for setup
                          context.push('/auth');
                        } else {
                          // Disable: require verification first
                          // 1. Try biometrics
                          final authState =
                              ref.read(authNotifierProvider).valueOrNull;
                          bool isVerified = false;

                          if (authState != null &&
                              authState.isBiometricAvailable) {
                            isVerified = await ref
                                .read(authNotifierProvider.notifier)
                                .authenticateWithBiometric();
                          }

                          // 2. Fallback to PIN dialogue
                          if (!isVerified) {
                            final enteredPin =
                                await _showPinConfirmationDialog();
                            if (enteredPin != null) {
                              isVerified = await ref
                                  .read(authNotifierProvider.notifier)
                                  .authenticateWithPin(enteredPin);
                            }
                          }

                          if (isVerified) {
                            await ref
                                .read(authNotifierProvider.notifier)
                                .clearPin();
                            await ref
                                .read(settingsNotifierProvider.notifier)
                                .updateSetting('isBiometricEnabled', false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Security lock successfully disabled.'),
                                  backgroundColor: Colors.teal,
                                ),
                              );
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Verification failed. App locks remain active.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- AUTOMATED IMPORT SERVICES SECTION ---
              _buildSectionHeader(context, 'Automated Sync Services'),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('SMS Bank Auto-Import',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: const Text(
                          'Parse income texts from trusted bank codes'),
                      secondary: const Icon(Icons.sms_failed_sharp),
                      value: settings.isSmsParsingEnabled,
                      onChanged: (bool value) async {
                        if (value) {
                          context.push('/permissions/sms');
                        } else {
                          await ref
                              .read(settingsNotifierProvider.notifier)
                              .updateSetting('isSmsParsingEnabled', false);
                          await SmsListenerService
                              .syncReceiverStateWithSettings(false);
                        }
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Notification Listener',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: const Text(
                          'Detect bank transactions from push notifications'),
                      secondary: const Icon(Icons.notifications_active),
                      value: settings.isNotificationListenerEnabled,
                      onChanged: (bool value) async {
                        await ref
                            .read(settingsNotifierProvider.notifier)
                            .updateSetting(
                                'isNotificationListenerEnabled', value);
                        if (value) {
                          _checkNotificationPermission();
                        }
                      },
                    ),
                    if (settings.isNotificationListenerEnabled) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'We read notifications from banking apps only, on-device, to detect transactions.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            if (!_isNotificationPermissionGranted) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .errorContainer
                                      .withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error
                                          .withOpacity(0.5)),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Notification Access required',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Theme.of(context).colorScheme.error,
                                        foregroundColor: Theme.of(context)
                                            .colorScheme
                                            .onError,
                                      ),
                                      onPressed: () {
                                        NotificationListenerService
                                            .requestPermission();
                                      },
                                      icon: const Icon(Icons.settings),
                                      label: const Text(
                                          'Enable Notification Access'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Theme(
                              data: Theme.of(context)
                                  .copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                leading: const Icon(Icons.playlist_add_check,
                                    size: 20),
                                title: const Text(
                                  'Monitored Banking Apps',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: const Text(
                                    'Auto-detects alerts from these exact apps'),
                                dense: true,
                                children: const [
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 12.0),
                                    child: Column(
                                      children: [
                                        _MonitoredPackageTile(
                                            appName: 'HDFC Bank',
                                            packageId: 'com.snapwork.hdfc'),
                                        _MonitoredPackageTile(
                                            appName: 'SBI YONO / Bank',
                                            packageId: 'com.sbi.sbifreedom'),
                                        _MonitoredPackageTile(
                                            appName: 'Paytm',
                                            packageId: 'net.one97.paytm'),
                                        _MonitoredPackageTile(
                                            appName: 'PhonePe',
                                            packageId: 'com.phonepe.app'),
                                        _MonitoredPackageTile(
                                            appName: 'Google Pay',
                                            packageId:
                                                'com.google.android.apps.nbu.paisa.user'),
                                        _MonitoredPackageTile(
                                            appName: 'ICICI iMobile',
                                            packageId: 'com.icicibank.imobile'),
                                        _MonitoredPackageTile(
                                            appName: 'Axis Mobile',
                                            packageId: 'com.axis.mobile'),
                                        _MonitoredPackageTile(
                                            appName: 'Amazon Pay',
                                            packageId:
                                                'in.amazon.mShop.android.shopping'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Privacy note
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.lock,
                                    size: 16,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Privacy Note: All notification contents are parsed entirely on-device and are never stored or transmitted.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontSize: 10.5,
                                            height: 1.3,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- GOOGLE ACCOUNT SYNC SECTION ---
              _buildSectionHeader(context, 'Google Account Sync'),
              const GoogleSyncCard(),
              const SizedBox(height: 20),

              // --- DATA MANAGEMENT & EXPIRY REPORTS SECTION ---
              _buildSectionHeader(context, 'Data Management'),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.picture_as_pdf_outlined),
                      title: const Text('Export PDF Statement',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: const Text(
                          'Generate transaction statement PDFs locally'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        context.push('/settings/export');
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: Icon(Icons.delete_forever_rounded,
                          color: Theme.of(context).colorScheme.error),
                      title: Text(
                        'Clear All Data',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                          'Wipe all local entries & settings completely'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: _showClearAllDataConfirmationDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- ABOUT SECTION ---
              _buildSectionHeader(context, 'About App'),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.category_outlined),
                      title: const Text('Manage Categories',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: const Text(
                          'Create and customize your tracker transaction categories'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        context.push('/categories');
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.shield_outlined),
                      title: const Text('Privacy Promise policy',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: const Text(
                          'Open source secure on-device policy statement'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        context.push('/settings/privacy');
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('Open Source Licenses',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: const Text(
                          'View license declarations of active packages'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => showLicensePage(context: context),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.bookmark_outline_rounded),
                      title: const Text('Tracker Version',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _appVersion,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const Center(
                child: Column(
                  children: [
                    Text(
                      'Transaction tracker',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '100% Client-Side Local Ledger. No Data Harvested.',
                      style: TextStyle(fontSize: 10.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 4.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

class _MonitoredPackageTile extends StatelessWidget {
  final String appName;
  final String packageId;

  const _MonitoredPackageTile({
    required this.appName,
    required this.packageId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  packageId,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
