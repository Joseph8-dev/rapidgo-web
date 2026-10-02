import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config/api_config.dart';
import '../models/order.dart';
import 'api_service.dart';

class OrderService {
  OrderService(this._api);

  final ApiService _api;

  Future<Order> place({
    required int shopId,
    required List<Map<String, dynamic>> items,
    required String idempotencyKey,
    required String fulfillment,
    String? seatLabel,
    String? note,
  }) async {
    final res = await _api.post(ApiConfig.orders, body: {
      'shop_id': shopId,
      'items': items,
      'idempotency_key': idempotencyKey,
      'fulfillment': fulfillment,
      if (seatLabel != null && seatLabel.isNotEmpty) 'seat_label': seatLabel,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return Order.fromJson(res['order'] as Map<String, dynamic>);
  }

  Future<List<Order>> list({int limit = 20, bool openOnly = false}) async {
    final res = await _api.get(ApiConfig.orders, query: {
      'limit': '$limit',
      if (openOnly) 'open': '1',
    });
    return (res['orders'] as List<dynamic>? ?? [])
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Order> byId(int id) async => Order.fromJson(await _api.get(ApiConfig.order(id)));

  Future<void> cancel(int id) => _api.post(ApiConfig.cancelOrder(id));

  Future<Order> confirmDelivery(int id, String idempotencyKey) async {
    final res = await _api.post(ApiConfig.confirmOrder(id), body: {
      'idempotency_key': idempotencyKey,
    });
    return Order.fromJson(res['order'] as Map<String, dynamic>);
  }
}

class OrderTracker extends ChangeNotifier with WidgetsBindingObserver {
  OrderTracker({required OrderService service, required this.orderId})
      : _service = service {
    WidgetsBinding.instance.addObserver(this);
  }

  final OrderService _service;
  final int orderId;

  Timer? _timer;
  DateTime? _startedAt;
  bool _disposed = false;
  bool _inFlight = false;

  Order? _order;
  Object? _error;
  bool _loading = true;

  Order? get order => _order;
  Object? get error => _error;
  bool get isLoading => _loading;
  bool get isPolling => _timer != null;

  Future<void> start() async {
    await refresh();
    _startedAt ??= DateTime.now();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (_disposed) return;

    final status = _order?.status;
    if (status != null && status.isFinished) return;

    if (_startedAt != null &&
        DateTime.now().difference(_startedAt!) > ApiConfig.pollCeiling) {
      return;
    }

    _timer = Timer(ApiConfig.orderPollInterval, () async {
      await refresh();
      _schedule();
    });
  }

  Future<void> refresh() async {
    if (_disposed || _inFlight) return;
    _inFlight = true;
    try {
      final fresh = await _service.byId(orderId);
      if (_disposed) return;
      final changed = _order?.status != fresh.status;
      _order = fresh;
      _error = null;
      _loading = false;
      if (changed) _startedAt = DateTime.now();
      _notify();
    } on ApiException catch (e) {
      if (_disposed) return;
      _loading = false;
      if (_order == null || !e.isNetwork) _error = e;
      _notify();
    } finally {
      _inFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(refresh().then((_) => _schedule()));
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
