import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/shop.dart';
import 'api_service.dart';
import 'browser_store.dart';

class AuthService extends ChangeNotifier {
  AuthService({BrowserStore? storage}) : _storage = storage ?? const BrowserStore.session();

  static const _kToken = 'rapidgo.token';
  static const _kName = 'rapidgo.name';
  static const _kUsername = 'rapidgo.username';
  static const _kGoeventId = 'rapidgo.goevent_id';
  static const _kBiometric = 'rapidgo.biometric_enabled';

  final BrowserStore _storage;

  ApiService? api;

  String? _token;
  String? _name;
  String? _username;
  String? _goeventId;
  bool _mustChangePassword = false;
  bool _restoring = true;
  Balance _balance = Balance.unknown;
  bool _disposed = false;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get mustChangePassword => _mustChangePassword;
  bool get isRestoring => _restoring;
  String? get name => _name;
  String? get username => _username;
  String? get goeventId => _goeventId;
  Balance get balance => _balance;

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  Future<String?> readToken() => _disposed ? Future.value(null) : Future.value(_token);

  Future<void> restore() async {
    try {
      _token = await _storage.read(key: _kToken);
      _name = await _storage.read(key: _kName);
      _username = await _storage.read(key: _kUsername);
      _goeventId = await _storage.read(key: _kGoeventId);

      if (_token != null) {
        await refreshProfile();
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _clear();
      } else if (e.needsPasswordChange) {
        _mustChangePassword = true;
      }
    } catch (_) {
      await _clear();
    } finally {
      _restoring = false;
      _safeNotify();
    }
  }

  Future<void> login({required String username, required String password}) async {
    final api = _requireApi();

    final res = await api.post(ApiConfig.login, body: {
      'username': username.trim().toUpperCase(),
      'password': password.trim(),
    });

    _token = res['token'] as String?;
    _mustChangePassword = res['must_change_password'] as bool? ?? false;

    final user = res['user'] as Map<String, dynamic>?;
    _name = user?['nombre'] as String?;
    _username = user?['username'] as String?;
    _goeventId = user?['goevent_id'] as String?;

    if (!_mustChangePassword) _balance = Balance.fromJson(res);

    await _persist();
    _safeNotify();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final api = _requireApi();
    await api.post(ApiConfig.changePassword, body: {
      'current_password': currentPassword.trim(),
      'new_password': newPassword,
    });
    _mustChangePassword = false;
    await refreshProfile();
    _safeNotify();
  }

  Future<void> refreshProfile() async {
    final api = _requireApi();
    try {
      final res = await api.get(ApiConfig.me);
      final user = res['user'] as Map<String, dynamic>?;
      _name = user?['nombre'] as String? ?? _name;
      _username = user?['username'] as String? ?? _username;
      _goeventId = user?['goevent_id'] as String? ?? _goeventId;
      _balance = Balance.fromJson(res);
      _mustChangePassword = false;
      await _persist();
    } on ApiException catch (e) {
      if (e.needsPasswordChange) {
        _mustChangePassword = true;
      } else {
        rethrow;
      }
    }
    _safeNotify();
  }

  Future<void> refreshBalance() async {
    if (!isAuthenticated || _mustChangePassword || _disposed) return;
    try {
      final res = await _requireApi().get(ApiConfig.balance);
      if (_disposed) return;
      _balance = Balance.fromJson(res);
      _safeNotify();
    } on ApiException catch (e) {
      if (e.needsPasswordChange) {
        _mustChangePassword = true;
        _safeNotify();
      }
    }
  }

  Future<void> logout({String? pushToken}) async {
    if (pushToken != null && isAuthenticated) {
      try {
        await api?.delete(ApiConfig.pushToken, body: {'token': pushToken});
      } catch (_) {}
    }
    await _clear();
    _safeNotify();
  }

  Future<void> onUnauthorized() async {
    await _clear();
    _safeNotify();
  }

  Future<bool> get biometricAvailable async => false;

  Future<bool> get biometricEnabled async =>
      (await _storage.read(key: _kBiometric)) == '1';

  Future<void> setBiometricEnabled(bool value) =>
      _storage.write(key: _kBiometric, value: value ? '1' : '0');

  Future<bool> authenticateBiometric() async => false;

  Future<void> _persist() async {
    if (_token == null) return;
    await _storage.write(key: _kToken, value: _token);
    if (_name != null) await _storage.write(key: _kName, value: _name);
    if (_username != null) await _storage.write(key: _kUsername, value: _username);
    if (_goeventId != null) await _storage.write(key: _kGoeventId, value: _goeventId);
  }

  Future<void> _clear() async {
    _token = null;
    _name = null;
    _goeventId = null;
    _mustChangePassword = false;
    _balance = Balance.unknown;
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kName);
    await _storage.delete(key: _kGoeventId);
  }

  ApiService _requireApi() {
    final a = api;
    if (a == null) throw StateError('AuthService.api was not wired');
    return a;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
