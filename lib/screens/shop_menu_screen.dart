import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/shop.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/responsive.dart';
import 'cart_screen.dart';

class ShopMenuScreen extends StatefulWidget {
  const ShopMenuScreen({super.key, required this.shop});

  final Shop shop;

  @override
  State<ShopMenuScreen> createState() => _ShopMenuScreenState();
}

class _ShopMenuScreenState extends State<ShopMenuScreen> {
  Catalog? _catalog;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final catalog = await context.read<CatalogService>().catalog(widget.shop.id);
      if (!mounted) return;

      final cart = context.read<CartService>();
      if (cart.shop?.id == widget.shop.id) {
        final changed = cart.reconcile([...catalog.items, ...catalog.combos]);
        if (changed.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Actualizamos tu carrito: ${changed.join(', ')}')),
          );
        }
      }

      setState(() {
        _catalog = catalog;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _add(Product product) async {
    final cart = context.read<CartService>();
    final shop = _catalog?.shop ?? widget.shop;

    final problem = cart.add(shop, product);
    if (problem == null) return;

    if (problem == 'switch_shop') {
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppDialogStyle.background,
          shape: AppDialogStyle.shape,
          title: const Text('¿Empezar un carrito nuevo?'),
          content: Text(
            'Tu carrito tiene productos de ${cart.shop?.name ?? 'otro negocio'}. '
            'Cada pedido va a un solo negocio.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Vaciar y agregar'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
      cart.clear();
      cart.add(shop, product);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
  }

  void _openCart() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final shop = _catalog?.shop ?? widget.shop;
    final expanded = Breakpoints.isExpanded(context);
    final compact = Breakpoints.isCompact(context);
    final showPanel = expanded && _catalog != null && _error == null;

    return Scaffold(
      appBar: AppBar(title: Text(shop.name)),
      body: SafeArea(
        child: ContentWidth(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _body(compact)),
              if (showPanel)
                Padding(
                  padding: EdgeInsets.fromLTRB(0, 28, Breakpoints.gutter(context), 28),
                  child: SizedBox(
                    width: 360,
                    child: _CartPanel(shop: shop, onCheckout: _openCart),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: cart.isEmpty || showPanel
          ? null
          : ReadableBar(
              maxWidth: 560,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _openCart,
                  child: Text('Ver carrito · ${cart.itemCount} · ${cart.total.bs()}'),
                ),
              ),
            ),
    );
  }

  Widget _body(bool compact) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return EmptyState(
        icon: Icons.wifi_off,
        title: 'No pudimos cargar el menú',
        message: _error!,
        action: SizedBox(
          width: 220,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              unawaited(_load());
            },
            child: const Text('Reintentar'),
          ),
        ),
      );
    }

    final catalog = _catalog!;
    if (catalog.isEmpty) {
      return EmptyState(
        icon: Icons.restaurant_menu,
        title: catalog.hasSoldOut ? 'Todo agotado por hoy' : 'Menú vacío',
        message: catalog.hasSoldOut
            ? '${catalog.shop.name} se quedó sin existencias esta noche. Prueba otro negocio.'
            : 'Este negocio todavía no cargó productos.',
      );
    }

    final cart = context.watch<CartService>();
    final sameShop = cart.shop?.id == catalog.shop.id;
    final gutter = Breakpoints.gutter(context);
    final open = catalog.shop.isOpen;

    Widget card(Product p) => compact
        ? ProductCard(
            product: p,
            qty: sameShop ? cart.qtyOf(p.id) : 0,
            onAdd: open ? () => _add(p) : () {},
            onRemove: () => cart.remove(p.id),
          )
        : ProductTile(
            product: p,
            qty: sameShop ? cart.qtyOf(p.id) : 0,
            enabled: open,
            onAdd: () => _add(p),
            onRemove: () => cart.remove(p.id),
          );

    List<Widget> section(String title, List<Product> products) {
      if (products.isEmpty) return const [];
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, compact ? 18 : 32, gutter, 14),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Text(title, style: AppText.display(compact ? 18 : 22)),
                const SizedBox(width: 10),
                Text('${products.length}', style: AppText.body(13, color: AppColors.grayLight)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          sliver: compact
              ? SliverList.separated(
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => card(products[i]),
                )
              : SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    mainAxisExtent: 214,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                  ),
                  itemCount: products.length,
                  itemBuilder: (_, i) => card(products[i]),
                ),
        ),
      ];
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.skyLight,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (!compact)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 0),
              sliver: SliverToBoxAdapter(child: _ShopHeader(shop: catalog.shop)),
            ),
          if (!open)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
              sliver: SliverToBoxAdapter(
                child: _Banner(
                  icon: Icons.pause_circle_outline,
                  color: AppColors.warning,
                  text: '${catalog.shop.name} pausó los pedidos. Puedes ver el menú, pero no pedir ahora.',
                ),
              ),
            ),
          if (catalog.hasSoldOut)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
              sliver: SliverToBoxAdapter(
                child: _Banner(
                  icon: Icons.info_outline,
                  color: AppColors.grayLight,
                  text: catalog.soldOutCount == 1
                      ? 'Un producto se agotó por hoy y no aparece en el menú.'
                      : '${catalog.soldOutCount} productos se agotaron por hoy y no aparecen en el menú.',
                ),
              ),
            ),
          ...section('Combos', catalog.combos),
          ...section('Productos', catalog.items),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppText.body(13))),
        ],
      ),
    );
  }
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (shop.category != null && shop.category!.isNotEmpty) shop.category!,
      '${shop.itemCount} productos',
      'Entrega en tu asiento',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius + 10),
        border: Border.all(color: AppColors.border),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceAlt, AppColors.midnight],
        ),
      ),
      child: Row(
        children: [
          ShopLogo(url: shop.logoUrl, size: 88),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shop.name, style: AppText.display(30), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text(subtitle, style: AppText.body(14, color: AppColors.grayLight)),
              ],
            ),
          ),
          StatusBadge(
            label: shop.isOpen ? 'Recibiendo pedidos' : 'Pausado',
            color: shop.isOpen ? AppColors.success : AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({required this.shop, required this.onCheckout});

  final Shop shop;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final otherShop = cart.isNotEmpty && cart.shop?.id != shop.id;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius + 4),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, color: AppColors.skyLight),
              const SizedBox(width: 10),
              Text('Tu pedido', style: AppText.display(18)),
              const Spacer(),
              if (cart.isNotEmpty)
                Text('${cart.itemCount}', style: AppText.figure(16)),
            ],
          ),
          const SizedBox(height: 16),
          if (cart.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Icon(Icons.add_shopping_cart, size: 40, color: AppColors.border),
                  const SizedBox(height: 12),
                  Text(
                    'Toca un producto para agregarlo.',
                    style: AppText.body(13, color: AppColors.grayLight),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            if (otherShop)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Productos de ${cart.shop?.name ?? 'otro negocio'}',
                  style: AppText.body(12, color: AppColors.warning),
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: cart.lines.length,
                separatorBuilder: (_, __) => const Divider(height: 18),
                itemBuilder: (_, i) {
                  final line = cart.lines[i];
                  return Row(
                    children: [
                      Text('${line.qty}×', style: AppText.figure(14)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          line.product.name,
                          style: AppText.body(13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(line.lineTotal.bs(), style: AppText.body(13, weight: FontWeight.w600)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Quitar uno',
                        onPressed: () => cart.remove(line.product.id),
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 28),
            Row(
              children: [
                Text('Subtotal', style: AppText.body(14, color: AppColors.grayLight)),
                const Spacer(),
                Text(cart.total.bs(), style: AppText.figure(20)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'El costo de entrega se calcula en el siguiente paso.',
              style: AppText.body(11, color: AppColors.grayLight),
            ),
            const SizedBox(height: 18),
            ElevatedButton(onPressed: onCheckout, child: const Text('Continuar')),
          ],
        ],
      ),
    );
  }
}
