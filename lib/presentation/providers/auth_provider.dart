import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tracker_app/core/services/biometric_service.dart';
import 'package:tracker_app/core/services/secure_storage_service.dart';

part 'auth_provider.g.dart';

class AuthState {
  final bool isLocked;
  final bool isBiometricAvailable;
  final bool hasPinSetup;

  const AuthState({
    required this.isLocked,
    required this.isBiometricAvailable,
    required this.hasPinSetup,
  });

  AuthState copyWith({
    bool? isLocked,
    bool? isBiometricAvailable,
    bool? hasPinSetup,
  }) {
    return AuthState(
      isLocked: isLocked ?? this.isLocked,
      isBiometricAvailable: isBiometricAvailable ?? this.isBiometricAvailable,
      hasPinSetup: hasPinSetup ?? this.hasPinSetup,
    );
  }
}

@riverpod
class AuthNotifier extends _$AuthNotifier {
  late BiometricService _biometricService;
  late SecureStorageService _secureStorageService;

  @override
  FutureOr<AuthState> build() async {
    _biometricService = BiometricService();
    _secureStorageService = SecureStorageService();

    final hasPin = await _secureStorageService.hasPin();
    final biometricAvail = await _biometricService.isAvailable();

    return AuthState(
      isLocked: hasPin,
      isBiometricAvailable: biometricAvail,
      hasPinSetup: hasPin,
    );
  }

  Future<void> initialize() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final hasPin = await _secureStorageService.hasPin();
      final biometricAvail = await _biometricService.isAvailable();
      return AuthState(
        isLocked: hasPin,
        isBiometricAvailable: biometricAvail,
        hasPinSetup: hasPin,
      );
    });
  }

  Future<bool> authenticateWithBiometric() async {
    final current = state.valueOrNull;
    if (current == null || !current.isBiometricAvailable) return false;

    final success = await _biometricService.authenticate('Authenticate to unlock Transaction tracker');
    if (success) {
      state = AsyncValue.data(current.copyWith(isLocked: false));
    }
    return success;
  }

  Future<bool> authenticateWithPin(String pin) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    final success = await _secureStorageService.verifyPin(pin);
    if (success) {
      state = AsyncValue.data(current.copyWith(isLocked: false));
    }
    return success;
  }

  void lock() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(isLocked: true));
  }

  Future<void> setupPin(String pin) async {
    final current = state.valueOrNull;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _secureStorageService.savePin(pin);
      final biometricAvail = await _biometricService.isAvailable();
      return AuthState(
        isLocked: false,
        isBiometricAvailable: biometricAvail,
        hasPinSetup: true,
      );
    });
  }

  Future<void> clearPin() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _secureStorageService.clearPin();
      final biometricAvail = await _biometricService.isAvailable();
      return AuthState(
        isLocked: false,
        isBiometricAvailable: biometricAvail,
        hasPinSetup: false,
      );
    });
  }
}
