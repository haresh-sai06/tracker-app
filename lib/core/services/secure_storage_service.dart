import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const String _pinKey = 'security_pin_hash';
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> savePin(String pin) async {
    await _storage.write(key: _pinKey, value: _hashPin(pin));
  }

  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinKey);
    if (storedHash == null) return false;
    return storedHash == _hashPin(pin);
  }

  Future<bool> hasPin() async {
    final storedHash = await _storage.read(key: _pinKey);
    return storedHash != null && storedHash.isNotEmpty;
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinKey);
  }
}
