import 'package:flutter/foundation.dart';

import '../utils/money.dart';
import 'product.dart';

@immutable
class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.isOpen,
    this.rif,
    this.logoUrl,
    this.category,
    this.itemCount = 0,
  });

  final int id;
  final String name;

  final bool isOpen;

  final String? rif;
  final String? logoUrl;
  final String? category;
  final int itemCount;

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
        id: json['id'] as int,
        name: (json['shop_name'] as String?) ?? 'Negocio',
        isOpen: json['is_open'] as bool? ?? false,
        rif: json['rif'] as String?,
        logoUrl: json['logo_url'] as String?,
        category: json['category'] as String?,
        itemCount: json['item_count'] is int
            ? json['item_count'] as int
            : int.tryParse('${json['item_count']}') ?? 0,
      );
}

@immutable
class Catalog {
  const Catalog({
    required this.shop,
    required this.items,
    required this.combos,
    this.soldOutCount = 0,
  });

  final Shop shop;
  final List<Product> items;
  final List<Product> combos;

  final int soldOutCount;

  bool get isEmpty => items.isEmpty && combos.isEmpty;
  bool get hasSoldOut => soldOutCount > 0;

  factory Catalog.fromJson(Map<String, dynamic> json) => Catalog(
        soldOutCount: json['sold_out_count'] as int? ?? 0,
        shop: Shop.fromJson(json['shop'] as Map<String, dynamic>),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        combos: (json['combos'] as List<dynamic>? ?? [])
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

@immutable
class Balance {
  const Balance({
    required this.cardLinked,
    this.saldo = Money.zero,
    this.held = Money.zero,
    this.available = Money.zero,
    this.goeventId,
    this.message,
  });

  final bool cardLinked;
  final Money saldo;
  final Money held;
  final Money available;
  final String? goeventId;

  final String? message;

  bool get hasHold => held.isPositive;

  static const Balance unknown = Balance(cardLinked: false);

  factory Balance.fromJson(Map<String, dynamic> json) => Balance(
        cardLinked: json['card_linked'] as bool? ?? false,
        saldo: Money.parse(json['saldo']),
        held: Money.parse(json['held']),
        available: Money.parse(json['available']),
        goeventId: json['goevent_id'] as String?,
        message: json['message'] as String?,
      );
}

@immutable
class CartItem {
  const CartItem({required this.product, required this.qty});

  final Product product;
  final int qty;

  Money get lineTotal => product.price * qty;

  CartItem withQty(int newQty) => CartItem(product: product, qty: newQty);

  Map<String, dynamic> toOrderLine() => {'product_id': product.id, 'qty': qty};
}
