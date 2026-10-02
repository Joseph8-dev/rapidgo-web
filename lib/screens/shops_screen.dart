import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shop.dart';
import '../models/order.dart';
import '../services/active_orders_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/go_logo.dart';
import '../widgets/responsive.dart';
import 'cart_screen.dart';
import 'order_tracking_screen.dart';
import 'orders_history_screen.dart';
import 'withdraw_screen.dart';
import 'shop_menu_screen.dart';

class ShopsScreen extends StatefulWidget {
  const ShopsScreen({super.key});

  @override
  State<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends State<ShopsScreen> with WidgetsBindingObserver {
  List<Shop> _shops = const [];
  bool _loading = true;
  String? _error;

  ActiveOrdersService? _watcher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());

    _watcher = context.read<ActiveOrdersService>()..addListener(_onOrderNews);
  }

  void _onOrderNews() {
    if (!mounted) return;
    final alerts = _watcher?.drainAlerts() ?? const <OrderAlert>[];
    for (final alert in alerts) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(alert.message),
          duration: Duration(seconds: alert.isBadNews ? 8 : 4),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => _openOrder(alert.order.id),
          ),
        ));
    }
    if (alerts.any((a) => a.isBadNews || a.order.status.isFinished)) {
      unawaited(context.read<AuthService>().refreshBalance());
    }
    setState(() {});
  }

  void _openOrder(int id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: id)),
    );
  }

  @override
  void dispose() {
    _watcher?.removeListener(_onOrderNews);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) unawaited(_load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final shops = await context.read<CatalogService>().shops();
      if (!mounted) return;
      setState(() {
        _shops = shops;
        _error = null;
        _loading = false;
      });
      unawaited(context.read<AuthService>().refreshBalance());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_shops.isEmpty) _error = e.message;
      });
    }
  }

  void _openShop(Shop shop) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ShopMenuScreen(shop: shop)),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _accountMenu(AuthService auth) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle),
      tooltip: 'Cuenta',
      position: PopupMenuPosition.under,
      color: AppColors.surfaceAlt,
      onSelected: (value) {
        if (value == 'logout') unawaited(_confirmLogout());
        if (value == 'withdraw') _push(const WithdrawScreen());
        if (value == 'orders') _push(const OrdersHistoryScreen());
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            auth.name ?? auth.username ?? 'Mi cuenta',
            style: AppText.body(13, color: AppColors.grayLight),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'orders',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.receipt_long, size: 20),
            title: Text('Mis pedidos'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'withdraw',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.account_balance, size: 20),
            title: Text('Retirar saldo'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout, size: 20),
            title: Text('Cerrar sesión'),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _appBar(AuthService auth, bool compact) {
    if (compact) {
      return AppBar(
        title: const GoLogo.appBar(),
        leading: IconButton(
          icon: const Icon(Icons.receipt_long),
          tooltip: 'Mis pedidos',
          onPressed: () => _push(const OrdersHistoryScreen()),
        ),
        actions: [_accountMenu(auth)],
      );
    }

    final gutter = Breakpoints.gutter(context);
    return AppBar(
      toolbarHeight: 84,
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: 0,
      title: ContentWidth(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Row(
            children: [
              const GoLogo.appBar(),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _push(const OrdersHistoryScreen()),
                icon: const Icon(Icons.receipt_long, size: 20),
                label: const Text('Mis pedidos'),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () => _push(const WithdrawScreen()),
                icon: const Icon(Icons.account_balance, size: 20),
                label: const Text('Retirar saldo'),
              ),
              const SizedBox(width: 16),
              BalancePill(balance: auth.balance),
              const SizedBox(width: 8),
              _accountMenu(auth),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final cart = context.watch<CartService>();
    final compact = Breakpoints.isCompact(context);
    final gutter = Breakpoints.gutter(context);
    final width = MediaQuery.sizeOf(context).width;
    final sidePad = width > Breakpoints.content
        ? (width - Breakpoints.content) / 2 + gutter
        : gutter;

    return Scaffold(
      appBar: _appBar(auth, compact),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.skyLight,
          backgroundColor: AppColors.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: ContentWidth(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(gutter, compact ? 12 : 36, gutter, 4),
                    child: _Header(compact: compact, balance: auth.balance),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: ContentWidth(
                  child: _LiveOrdersBanner(gutter: gutter, compact: compact),
                ),
              ),
              if (!auth.balance.cardLinked && auth.balance.message != null)
                SliverToBoxAdapter(
                  child: ContentWidth(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
                      child: _Notice(message: auth.balance.message!),
                    ),
                  ),
                ),
              if (!compact && _shops.isNotEmpty)
                SliverToBoxAdapter(
                  child: ContentWidth(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(gutter, 32, gutter, 16),
                      child: Row(
                        children: [
                          Text('Negocios', style: AppText.display(22)),
                          const SizedBox(width: 12),
                          Text(
                            '${_shops.where((x) => x.isOpen).length} abiertos de ${_shops.length}',
                            style: AppText.body(13, color: AppColors.grayLight),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ..._content(compact, sidePad),
            ],
          ),
        ),
      ),
      floatingActionButton: cart.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _push(const CartScreen()),
              backgroundColor: AppColors.skyLight,
              foregroundColor: AppColors.midnight,
              icon: const Icon(Icons.shopping_bag),
              label: Text('${cart.itemCount} · ${cart.total.bs()}'),
            ),
    );
  }

  List<Widget> _content(bool compact, double sidePad) {
    if (_loading && _shops.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null && _shops.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.wifi_off,
            title: 'No pudimos cargar los negocios',
            message: _error!,
            action: SizedBox(
              width: 220,
              child: ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
            ),
          ),
        ),
      ];
    }
    if (_shops.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.storefront,
            title: 'Todavía no hay negocios',
            message: 'Ningún negocio está registrado para pedidos en este momento.',
          ),
        ),
      ];
    }

    final shops = [..._shops]..sort((a, b) {
        if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    if (compact) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(sidePad, 12, sidePad, 96),
          sliver: SliverList.separated(
            itemCount: shops.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => ShopCard(shop: shops[i], onTap: () => _openShop(shops[i])),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(sidePad, 0, sidePad, 120),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 380,
            mainAxisExtent: 228,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: shops.length,
          itemBuilder: (_, i) => ShopTile(shop: shops[i], onTap: () => _openShop(shops[i])),
        ),
      ),
    ];
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDialogStyle.background,
        shape: AppDialogStyle.shape,
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tus pedidos en curso siguen activos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<CartService>().clear();
    await context.read<AuthService>().logout();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.compact, required this.balance});

  final bool compact;
  final Balance balance;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pide desde tu asiento', style: AppText.display(22)),
                const SizedBox(height: 4),
                Text(
                  'Elige un negocio del estadio.',
                  style: AppText.body(13, color: AppColors.grayLight),
                ),
              ],
            ),
          ),
          BalancePill(balance: balance),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(36, 36, 36, 36),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pide desde tu asiento', style: AppText.display(38)),
                const SizedBox(height: 10),
                Text(
                  'Elige un negocio, arma tu pedido y te lo llevamos. '
                  'Pagas con tu tarjeta GoEvent cuando lo recibes.',
                  style: AppText.body(15, color: AppColors.grayLight, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          const Icon(Icons.stadium_outlined, size: 96, color: AppColors.skyDeep),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppText.body(13))),
        ],
      ),
    );
  }
}

class _LiveOrdersBanner extends StatefulWidget {
  const _LiveOrdersBanner({required this.gutter, required this.compact});

  final double gutter;
  final bool compact;

  @override
  State<_LiveOrdersBanner> createState() => _LiveOrdersBannerState();
}

class _LiveOrdersBannerState extends State<_LiveOrdersBanner> {
  late final PageController _controller = PageController(viewportFraction: 0.96);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final watcher = context.watch<ActiveOrdersService>();
    final orders = watcher.live;
    if (orders.isEmpty) return const SizedBox.shrink();

    final sorted = [...orders]
      ..sort((a, b) => b.status.railIndex.compareTo(a.status.railIndex));

    final page = _page.clamp(0, sorted.length - 1);

    if (!widget.compact) {
      return Padding(
        padding: EdgeInsets.fromLTRB(widget.gutter, 28, widget.gutter, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tus pedidos en curso', style: AppText.display(18)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: sorted
                  .map((o) => SizedBox(width: 380, height: 76, child: _LiveOrderCard(order: o)))
                  .toList(),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 76,
            child: PageView.builder(
              controller: _controller,
              itemCount: sorted.length,
              onPageChanged: (i) => setState(() => _page = i),
              padEnds: false,
              itemBuilder: (_, i) => Padding(
                padding: EdgeInsets.only(
                  left: i == 0 ? 16 : 6,
                  right: i == sorted.length - 1 ? 16 : 6,
                ),
                child: _LiveOrderCard(order: sorted[i]),
              ),
            ),
          ),
          if (sorted.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(sorted.length, (i) {
                  final active = i == page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? AppColors.skyLight : AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveOrderCard extends StatelessWidget {
  const _LiveOrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(order.status.wire);

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: order.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.midnight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.6)),
              ),
              child: Text(order.code, style: AppText.display(15, color: color)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    order.status.label,
                    style: AppText.body(14, weight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.shopName,
                    style: AppText.body(12, color: AppColors.grayLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(order.total.bs(), style: AppText.figure(13)),
            const Icon(Icons.chevron_right, color: AppColors.skyDeep),
          ],
        ),
      ),
    );
  }
}
