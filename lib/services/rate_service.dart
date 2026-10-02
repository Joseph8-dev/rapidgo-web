import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'api_service.dart';

class RateService extends ChangeNotifier {
  RateService(this._api);

  final ApiService _api;

  static const Duration _ttl = Duration(minutes: 10);

  double? _rate;
  DateTime? _fetchedAt;
  bool _disposed = false;
  Future<void>? _inFlight;

  double? get rate => _rate;
  bool get hasRate => _rate != null && _rate! > 0;
  DateTime? get fetchedAt => _fetchedAt;

  bool get _isStale =>
      _fetchedAt == null || DateTime.now().difference(_fetchedAt!) > _ttl;

  Future<void> ensureFresh({bool force = false}) {
    if (!force && !_isStale) return Future.value();
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  Future<void> _fetch() async {
    try {
      final res = await _api.get(ApiConfig.rate);
      if (_disposed) return;
      final value = res['rate'];
      final parsed = value is num ? value.toDouble() : double.tryParse('$value');
      if (parsed != null && parsed > 0) {
        _rate = parsed;
        _fetchedAt = DateTime.now();
        _notify();
      }
    } on ApiException {
    }
  }

  void seed(Object? value) {
    if (_disposed || value == null) return;
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    if (parsed == null || parsed <= 0) return;
    if (_rate != null && !_isStale) return;
    _rate = parsed;
    _fetchedAt = DateTime.now();
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
