import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/product.dart';
import '../models/shop.dart';
import '../utils/money.dart';

class CartService extends ChangeNotifier {
  final Map<int, CartItem> _lines = {};
  Shop? _shop;
  String? _idempotencyKey;
  bool _disposed = false;

  static const int maxQtyPerProduct = 20;
  static const int maxLines = 30;

  Shop? get shop => _shop;
  bool get isEmpty => _lines.isEmpty;
  bool get isNotEmpty => _lines.isNotEmpty;
  int get lineCount => _lines.length;
  int get itemCount => _lines.values.fold(0, (sum, l) => sum + l.qty);

  List<CartItem> get lines => _lines.values.toList(growable: false);

  Money get total =>
      _lines.values.fold(Money.zero, (sum, l) => sum + l.lineTotal);

  int qtyOf(int productId) => _lines[productId]?.qty ?? 0;

  String get idempotencyKey => _idempotencyKey ??= const Uuid().v4();

  void consumeIdempotencyKey() => _idempotencyKey = null;

  String? add(Shop shop, Product product, {int qty = 1}) {
    if (!product.available) return '${product.name} no está disponible.';

    if (_shop != null && _shop!.id != shop.id && _lines.isNotEmpty) {
      return 'switch_shop';
    }
    if (_lines.length >= maxLines && !_lines.containsKey(product.id)) {
      return 'Máximo $maxLines productos distintos por pedido.';
    }

    final current = _lines[product.id]?.qty ?? 0;
    final next = current + qty;
    if (next > maxQtyPerProduct) {
      return 'Máximo $maxQtyPerProduct unidades de ${product.name}.';
    }

    _shop = shop;
    _lines[product.id] = CartItem(product: product, qty: next);
    _notify();
    return null;
  }

  void remove(int productId) {
    final line = _lines[productId];
    if (line == null) return;
    if (line.qty <= 1) {
      _lines.remove(productId);
    } else {
      _lines[productId] = line.withQty(line.qty - 1);
    }
    if (_lines.isEmpty) _shop = null;
    _notify();
  }

  void removeLine(int productId) {
    if (_lines.remove(productId) == null) return;
    if (_lines.isEmpty) _shop = null;
    _notify();
  }

  void clear({bool keepKey = false}) {
    if (_lines.isEmpty && _shop == null) return;
    _lines.clear();
    _shop = null;
    if (!keepKey) _idempotencyKey = null;
    _notify();
  }

  List<String> reconcile(List<Product> menu) {
    final byId = {for (final p in menu) p.id: p};
    final dropped = <String>[];

    for (final id in _lines.keys.toList()) {
      final fresh = byId[id];
      final line = _lines[id]!;
      if (fresh == null || !fresh.available) {
        dropped.add(line.product.name);
        _lines.remove(id);
      } else if (fresh.price != line.product.price) {
        dropped.add('${fresh.name} (precio actualizado)');
        _lines[id] = CartItem(product: fresh, qty: line.qty);
      }
    }
    if (_lines.isEmpty) _shop = null;
    if (dropped.isNotEmpty) _notify();
    return dropped;
  }

  List<Map<String, dynamic>> toOrderLines() =>
      _lines.values.map((l) => l.toOrderLine()).toList(growable: false);

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _lines.clear();
    super.dispose();
  }
}
