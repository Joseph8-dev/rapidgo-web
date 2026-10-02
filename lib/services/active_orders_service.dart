import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/order.dart';
import 'api_service.dart';
import 'order_service.dart';

@immutable
class OrderAlert {
  const OrderAlert({required this.order, required this.previous});

  final Order order;
  final OrderStatus previous;

  bool get isBadNews => order.status == OrderStatus.rejected ||
      order.status == OrderStatus.cancelled;

  String get message {
    switch (order.status) {
      case OrderStatus.accepted:
        return '${order.shopName} confirmó tu pedido ${order.code}.';
      case OrderStatus.preparing:
        return '${order.shopName} está preparando ${order.code}.';
      case OrderStatus.ready:
        return 'Tu pedido ${order.code} está listo. Un mesero va en camino.';
      case OrderStatus.inTransit:
        return '${order.code} va hacia tu asiento. Ten tu tarjeta a la mano.';
      case OrderStatus.delivered:
        return 'Entregado. Cobramos ${order.total.format()} por ${order.code}.';
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        return '${order.shopName} canceló ${order.code}. No se te cobró nada.';
      case OrderStatus.paymentFailed:
        return 'El cobro de ${order.code} no pasó. Recarga y el mesero reintenta.';
      default:
        return 'Tu pedido ${order.code} cambió de estado.';
    }
  }
}

class ActiveOrdersService extends ChangeNotifier with WidgetsBindingObserver {
  ActiveOrdersService(this._orders) {
    WidgetsBinding.instance.addObserver(this);
  }

  final OrderService _orders;

  static const Duration _activeInterval = Duration(seconds: 15);
  static const Duration _idleInterval = Duration(minutes: 2);

  Timer? _timer;
  bool _disposed = false;
  bool _inFlight = false;
  bool _enabled = false;

  List<Order> _live = const [];
  final Map<int, OrderStatus> _lastSeen = {};

  final List<OrderAlert> _pending = [];

  List<Order> get live => _live;
  bool get hasLive => _live.isNotEmpty;
  int get liveCount => _live.length;

  Order? get mostAdvanced {
    if (_live.isEmpty) return null;
    final sorted = [..._live]
      ..sort((a, b) => b.status.railIndex.compareTo(a.status.railIndex));
    return sorted.first;
  }

  List<OrderAlert> drainAlerts() {
    if (_pending.isEmpty) return const [];
    final out = List<OrderAlert>.unmodifiable(_pending);
    _pending.clear();
    return out;
  }

  void start() {
    if (_enabled || _disposed) return;
    _enabled = true;
    unawaited(refresh().then((_) => _schedule()));
  }

  void stop() {
    _enabled = false;
    _timer?.cancel();
    _timer = null;
    _live = const [];
    _lastSeen.clear();
    _pending.clear();
    _notify();
  }

  void _schedule() {
    _timer?.cancel();
    if (_disposed || !_enabled) return;
    _timer = Timer(hasLive ? _activeInterval : _idleInterval, () async {
      await refresh();
      _schedule();
    });
  }

  Future<void> refresh() async {
    if (_disposed || !_enabled || _inFlight) return;
    _inFlight = true;
    try {
      final fresh = await _orders.list(limit: 10, openOnly: true);
      if (_disposed) return;

      for (final order in fresh) {
        final previous = _lastSeen[order.id];
        if (previous != null && previous != order.status) {
          _pending.add(OrderAlert(order: order, previous: previous));
        }
        _lastSeen[order.id] = order.status;
      }

      final stillOpen = fresh.map((o) => o.id).toSet();
      for (final id in _lastSeen.keys.toList()) {
        if (stillOpen.contains(id)) continue;
        final previous = _lastSeen.remove(id);
        if (previous == null) continue;
        try {
          final closed = await _orders.byId(id);
          if (_disposed) return;
          if (closed.status != previous) {
            _pending.add(OrderAlert(order: closed, previous: previous));
          }
        } on ApiException {
        }
      }

      _live = fresh;
      _notify();
    } on ApiException {
    } finally {
      _inFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed || !_enabled) return;
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
