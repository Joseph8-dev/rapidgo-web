import 'package:flutter/material.dart';

import '../utils/money.dart';

@immutable
class Product {
  const Product({
    required this.id,
    required this.kind,
    required this.name,
    required this.price,
    this.icon,
    this.imageUrl,
    this.available = true,
  });

  final int id;
  final String kind;
  final String name;
  final Money price;
  final String? icon;
  final String? imageUrl;

  final bool available;

  bool get isCombo => kind == 'combo';

  IconData get iconData => ProductIcons.resolve(icon, isCombo: isCombo);

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as int,
        kind: (json['kind'] as String?) ?? 'item',
        name: (json['name'] as String?) ?? 'Producto',
        price: Money.parse(json['price']),
        icon: json['icon'] as String?,
        imageUrl: json['image_url'] as String?,
        available: json['available'] as bool? ?? true,
      );
}

class ProductIcons {
  ProductIcons._();

  static const Map<String, IconData> byName = {
    'fastfood': Icons.fastfood,
    'lunch_dining': Icons.lunch_dining,
    'dinner_dining': Icons.dinner_dining,
    'local_pizza': Icons.local_pizza,
    'bakery_dining': Icons.bakery_dining,
    'ramen_dining': Icons.ramen_dining,
    'kebab_dining': Icons.kebab_dining,
    'icecream': Icons.icecream,
    'cookie': Icons.cookie,
    'cake': Icons.cake,
    'local_cafe': Icons.local_cafe,
    'coffee': Icons.coffee,
    'local_drink': Icons.local_drink,
    'local_bar': Icons.local_bar,
    'sports_bar': Icons.sports_bar,
    'water_drop': Icons.water_drop,
    'emoji_food_beverage': Icons.emoji_food_beverage,
    'set_meal': Icons.set_meal,
    'restaurant': Icons.restaurant,
    'egg_alt': Icons.egg_alt,
    'shopping_bag': Icons.shopping_bag,
    'card_giftcard': Icons.card_giftcard,
    'sports_soccer': Icons.sports_soccer,
    'checkroom': Icons.checkroom,
    'store': Icons.store,
  };

  static IconData resolve(String? name, {bool isCombo = false}) {
    if (name != null) {
      final hit = byName[name];
      if (hit != null) return hit;
    }
    return isCombo ? Icons.set_meal : Icons.fastfood;
  }

  static List<String> get names => byName.keys.toList(growable: false);
}
