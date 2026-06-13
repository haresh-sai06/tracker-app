import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tracker_app/core/services/permission_service.dart';
import 'package:tracker_app/core/services/sms_listener_service.dart';
import 'package:tracker_app/presentation/providers/settings_provider.dart';

class SmsPermissionPage extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const SmsPermissionPage({
    super.key,
    required this.onComplete,
  });

  @override
  ConsumerState<SmsPermissionPage> createState() => _SmsPermissionPageState();
}

class _SmsPermissionPageState extends ConsumerState<SmsPermissionPage> {
  PermissionStatus _status = PermissionStatus.denied;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    setState(() => _isLoading = true);
    final status = await PermissionService.checkSmsPermission();
    if (mounted) {
      setState(() {
        _status = status;
        _isLoading = false;
      });
      if (status.isGranted) {
        // Ensure in DB we also mark as active
        final settings = ref.read(settingsNotifierProvider).valueOrNull;
        if (settings != null && !settings.isSmsParsingEnabled) {
          await ref.read(settingsNotifierProvider.notifier).updateSettings(
            settings.copyWith(isSmsParsingEnabled: true),
          );
          await SmsListenerService.syncReceiverStateWithSettings(true);
        }
        widget.onComplete();
      }
    }
  }

  Future<void> _requestPermission() async {
    final granted = await PermissionService.requestSmsPermission();
    if (mounted) {
      final status = await PermissionService.checkSmsPermission();
      setState(() {
        _status = status;
      });

      if (granted) {
        final settings = ref.read(settingsNotifierProvider).valueOrNull;
        if (settings != null) {
          await ref.read(settingsNotifierProvider.notifier).updateSettings(
            settings.copyWith(isSmsParsingEnabled: true),
          );
          await SmsListenerService.syncReceiverStateWithSettings(true);
        }
        widget.onComplete();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS permission denied. Enable it to parse transactions automatically.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final theme = Theme.of(context);
    final isPermanentlyDenied = _status.isPermanentlyDenied;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local SMS Parsing'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Privacy Badge / Icon Header
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(50),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.security,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // App Title & Rationale
              Center(
                child: Text(
                  'On-Device SMS Automation',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Your SMS messages are processed ONLY on this device. Zero data is sent to any server.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // Two sides: What is read vs What is NOT
              Expanded(
                child: ListView(
                  children: [
                    _buildSectionHeader(context, 'What is processed locally', Icons.check_circle_outline, Colors.green),
                    const SizedBox(height: 8),
                    _buildBulletItem(context, 'Incoming bank transactional SMS notifications.'),
                    _buildBulletItem(context, 'Transaction amount, merchant name, and date details.'),
                    _buildBulletItem(context, 'Approximate credit/debit transaction category structure.'),
                    const SizedBox(height: 20),
                    _buildSectionHeader(context, 'What is NEVER collected', Icons.cancel_outlined, Colors.red),
                    const SizedBox(height: 8),
                    _buildBulletItem(context, 'Personal chat messages and thread conversations.'),
                    _buildBulletItem(context, 'One-Time Passwords (OTPs), log-in codes, and passwords.'),
                    _buildBulletItem(context, 'Cloud storage: absolutely NO SMS text leaves your phone.'),
                  ],
                ),
              ),

              // Action Buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isPermanentlyDenied) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => openAppSettings(),
                      icon: const Icon(Icons.settings),
                      label: const Text('Open App Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _requestPermission,
                      icon: const Icon(Icons.sms_rounded),
                      label: const Text('Enable SMS Parsing', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: widget.onComplete,
                    child: Text(
                      'Skip & Standard Manual Flow',
                      style: TextStyle(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBulletItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 28.0, bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
