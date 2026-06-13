import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_app/presentation/providers/auth_provider.dart';
import 'package:tracker_app/presentation/providers/repository_providers.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  
  // PIN states
  String _enteredPin = '';
  String _firstStepPin = ''; // Used for matching during registration
  bool _isConfirming = false; // Registration step trigger
  
  // UI views
  bool? _showPinScreen; // Toggle for PIN vs Biometric view
  bool _hasAttemptedAutoBiometric = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometrics() async {
    final success = await ref.read(authNotifierProvider.notifier).authenticateWithBiometric();
    if (success && mounted) {
      context.go('/dashboard');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric authentication failed or was cancelled.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onKeyPress(String digit) {
    if (_enteredPin.length >= 6) return;
    
    setState(() {
      _enteredPin += digit;
    });

    if (_enteredPin.length == 6) {
      _handlePinComplete();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Future<void> _handlePinComplete() async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState == null) return;

    if (!authState.hasPinSetup) {
      // Setup PIN Process
      if (!_isConfirming) {
        // First step complete
        setState(() {
          _firstStepPin = _enteredPin;
          _enteredPin = '';
          _isConfirming = true;
        });
      } else {
        // Confirmation step
        if (_firstStepPin == _enteredPin) {
          // PINs match! Save and enable
          await ref.read(authNotifierProvider.notifier).setupPin(_enteredPin);
          
          // Persist settings
          final settingsResult = await ref.read(settingsRepositoryProvider).getSettings();
          settingsResult.fold((_) {}, (settings) async {
            await ref.read(settingsRepositoryProvider).updateSettings(
              settings.copyWith(
                isBiometricEnabled: true,
                defaultAccountId: settings.defaultAccountId ?? 'primary_bank',
              ),
            );
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PIN successfully configured and locked.'),
                backgroundColor: Colors.green,
              ),
            );
            context.go('/dashboard');
          }
        } else {
          // PINs mismatch
          _triggerShake();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PINs do not match. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() {
            _enteredPin = '';
            _firstStepPin = '';
            _isConfirming = false;
          });
        }
      }
    } else {
      // Unlocking Process
      final success = await ref.read(authNotifierProvider.notifier).authenticateWithPin(_enteredPin);
      if (success) {
        if (mounted) {
          context.go('/dashboard');
        }
      } else {
        // Incorrect Pin
        _triggerShake();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect PIN. Please try again.'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 1),
          ),
        );
        setState(() {
          _enteredPin = '';
        });
      }
    }
  }

  void _triggerShake() {
    _shakeController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final authStateAsync = ref.watch(authNotifierProvider);

    return Scaffold(
      body: authStateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (authState) {
          final isSetupMode = !authState.hasPinSetup;
          
          if (_showPinScreen == null) {
            _showPinScreen = isSetupMode || !authState.isBiometricAvailable;
          }

          if (!isSetupMode && authState.isBiometricAvailable && !_hasAttemptedAutoBiometric) {
            _hasAttemptedAutoBiometric = true;
            _showPinScreen = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _triggerBiometrics();
              }
            });
          }
          
          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                      minWidth: constraints.maxWidth,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 32),
                            // App Branding / Logo Action
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withAlpha(20),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSetupMode ? Icons.security : Icons.lock_outline,
                                size: 48,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Display Header based on active state
                            if (isSetupMode) ...[
                              Text(
                                _isConfirming ? 'Confirm PIN' : 'Create Security PIN',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isConfirming 
                                    ? 'Re-enter your 6-digit PIN to establish security.'
                                    : 'Choose a 6-digit PIN to secure your transaction and account details.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ] else ...[
                              Text(
                                'Transaction tracker',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _showPinScreen == true 
                                    ? 'Enter secure pass PIN to unlock app records.'
                                    : 'Authenticating your device securely.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            
                            const SizedBox(height: 48),

                            // Main Content switching between Prominent Biometric View and Custom NumPad
                            if (!isSetupMode && _showPinScreen == false && authState.isBiometricAvailable) ...[
                              _buildProminentBiometricView(),
                            ] else ...[
                              _buildPinEntryWithNumpad(authState.isBiometricAvailable),
                            ],

                            const Spacer(),

                            // Footer message explaining security rules (No pin recovery)
                            Opacity(
                              opacity: 0.6,
                              child: Text(
                                'ℹ️ For security, there is no online backup of your PIN.\nClearing app data or re-installing resets the tracker.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
            ),
          );
        },
      ),
    );
  }

  // --- UI Layouts ---

  Widget _buildProminentBiometricView() {
    return Column(
      key: const ValueKey('biometric_view'),
      children: [
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _triggerBiometrics,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withAlpha(40),
                  blurRadius: 24,
                  spreadRadius: 4,
                )
              ],
            ),
            child: Icon(
              Icons.fingerprint,
              size: 80,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Unlock using biometrics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Click fingerprint above to try again',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 40),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _showPinScreen = true;
            });
          },
          icon: const Icon(Icons.pin, size: 18),
          label: const Text('Use PIN instead'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(200, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPinEntryWithNumpad(bool isBiometricAvailable) {
    return Column(
      key: const ValueKey('pin_view'),
      children: [
        // Dots Indicator with Shake effect
        ShakeWidget(
          controller: _shakeController,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final isEntered = index < _enteredPin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: isEntered ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isEntered ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                    width: 2.5,
                  ),
                ),
              );
            }),
          ),
        ),
        
        const SizedBox(height: 40),

        // 3x4 custom keyboard layout
        _buildNumPad(isBiometricAvailable),

        const SizedBox(height: 24),

        // Toggle back to biometrics if available
        if (isBiometricAvailable && !(!ref.watch(authNotifierProvider).valueOrNull!.hasPinSetup)) ...[
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showPinScreen = false;
              });
              _triggerBiometrics();
            },
            icon: const Icon(Icons.fingerprint, size: 18),
            label: const Text('Use Fingerprint instead'),
          ),
        ],
      ],
    );
  }

  Widget _buildNumPad(bool isBiometricAvailable) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumButton('1'),
              _buildNumButton('2'),
              _buildNumButton('3'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumButton('4'),
              _buildNumButton('5'),
              _buildNumButton('6'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumButton('7'),
              _buildNumButton('8'),
              _buildNumButton('9'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBiometricOrEmptyButton(isBiometricAvailable),
              _buildNumButton('0'),
              _buildBackspaceButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumButton(String digit) {
    return SizedBox(
      width: 76,
      height: 76,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(120)),
          padding: EdgeInsets.zero,
        ),
        onPressed: () => _onKeyPress(digit),
        child: Text(
          digit,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricOrEmptyButton(bool isBiometricAvailable) {
    final isSetupMode = !ref.watch(authNotifierProvider).valueOrNull!.hasPinSetup;
    if (isBiometricAvailable && !isSetupMode) {
      return SizedBox(
        width: 76,
        height: 76,
        child: IconButton(
          icon: Icon(
            Icons.fingerprint,
            size: 38,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: _triggerBiometrics,
        ),
      );
    } else {
      return const SizedBox(width: 76, height: 76);
    }
  }

  Widget _buildBackspaceButton() {
    return SizedBox(
      width: 76,
      height: 76,
      child: IconButton(
        icon: Icon(
          Icons.backspace_outlined,
          size: 26,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onPressed: _onBackspace,
      ),
    );
  }
}

// Custom shake widget helper with offset animation sequence
class ShakeWidget extends StatefulWidget {
  final Widget child;
  final AnimationController controller;

  const ShakeWidget({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget> {
  late final Animation<double> _offsetAnimation = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 15.0), weight: 1),
    TweenSequenceItem(tween: Tween<double>(begin: 15.0, end: -15.0), weight: 2),
    TweenSequenceItem(tween: Tween<double>(begin: -15.0, end: 12.0), weight: 2),
    TweenSequenceItem(tween: Tween<double>(begin: 12.0, end: -12.0), weight: 2),
    TweenSequenceItem(tween: Tween<double>(begin: -12.0, end: 0.0), weight: 1),
  ]).animate(widget.controller);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offsetAnimation.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
