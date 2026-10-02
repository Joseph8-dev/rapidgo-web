import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/shop.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/config_service.dart';
import '../services/order_service.dart';
import '../services/rate_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/app_widgets.dart';
import '../widgets/responsive.dart';
import 'order_tracking_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _seatController = TextEditingController();
  final _noteController = TextEditingController();
  final _seatFocus = FocusNode();

  static const String _fulfillment = 'seat';

  bool _placing = false;
  String? _error;

  RapidGoConfig _config = RapidGoConfig.fallback;
  bool _configLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<AuthService>().refreshBalance());
      unawaited(_loadConfig());
    });
  }

  @override
  void dispose() {
    _seatController.dispose();
    _noteController.dispose();
    _seatFocus.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final service = context.read<ConfigService>();
    final config = await service.load();
    if (!mounted) return;
    setState(() {
      _config = config;
      _configLoaded = service.isLoaded;
    });
  }

  Future<void> _place() async {
    if (_placing) return;

    final cart = context.read<CartService>();
    final auth = context.read<AuthService>();
    final orders = context.read<OrderService>();
    final shop = cart.shop;
    if (shop == null || cart.isEmpty) return;

    FocusScope.of(context).unfocus();

    if (_seatController.text.trim().isEmpty) {
      setState(() => _error = 'Escribe tu asiento para que el mesero te encuentre.');
      _seatFocus.requestFocus();
      return;
    }

    if (!_configLoaded) {
      await _loadConfig();
      if (!mounted) return;
      if (!_configLoaded) {
        setState(() => _error = 'No pudimos confirmar los precios. Revisa tu conexión.');
        return;
      }
    }

    setState(() {
      _placing = true;
      _error = null;
    });

    try {
      final order = await orders.place(
        shopId: shop.id,
        items: cart.toOrderLines(),
        idempotencyKey: cart.idempotencyKey,
        fulfillment: _fulfillment,
        seatLabel: _seatController.text.trim(),
        note: _noteController.text.trim(),
      );

      cart.consumeIdempotencyKey();
      cart.clear();
      unawaited(auth.refreshBalance());

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: order.id)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = _explain(e));
      if (e.code == 'insufficient_funds') unawaited(auth.refreshBalance());
      if (e.code == 'order_too_large') unawaited(_loadConfig());
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos enviar tu pedido. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  String _explain(ApiException e) {
    switch (e.code) {
      case 'insufficient_funds':
        final available = Money.parse(e.data?['available']);
        return 'No tienes saldo suficiente. Disponible: ${available.format()}. '
            'Recarga en taquilla o quita algo del carrito.';
      case 'shop_closed':
        return 'El negocio pausó los pedidos mientras armabas el carrito.';
      case 'item_unavailable':
        return 'Algo del carrito se agotó. Vuelve al menú para actualizarlo.';
      case 'no_card_linked':
        return 'Tu tarjeta no está activa. Acude a taquilla para vincular una nueva.';
      case 'card_inactive':
        return 'Tu tarjeta está bloqueada. Acude a taquilla.';
      case 'too_many_open_orders':
        return '${e.message} Míralos en "Mis pedidos".';
      case 'pickup_not_supported':
      case 'order_too_large':
        return e.message;
      default:
        return e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final auth = context.watch<AuthService>();
    final balance = auth.balance;

    final subtotal = cart.total;
    final fee = _config.feeFor(subtotal);
    final total = subtotal + fee;

    final affordable = balance.cardLinked && balance.available >= total;
    final canPlace = cart.isNotEmpty && affordable && !_placing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu pedido'),
        actions: [
          if (cart.isNotEmpty)
            TextButton(
              onPressed: _placing ? null : () => cart.clear(),
              child: const Text('Vaciar'),
            ),
        ],
      ),
      body: ReadableSafeArea(
        child: cart.isEmpty
            ? const EmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'Tu carrito está vacío',
                message: 'Elige un negocio y arma tu pedido.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Text(cart.shop?.name ?? '', style: AppText.display(20)),
                  const SizedBox(height: 12),
                  ...cart.lines.map((line) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Icon(line.product.iconData, color: AppColors.skyDeep),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        line.product.name,
                                        style: AppText.body(15, weight: FontWeight.w600),
                                      ),
                                      Text(
                                        '${line.qty} × ${line.product.price.format()}',
                                        style: AppText.body(12, color: AppColors.grayLight),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(line.lineTotal.format(), style: AppText.figure(15)),
                                IconButton(
                                  onPressed: _placing
                                      ? null
                                      : () => cart.removeLine(line.product.id),
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'Quitar',
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),
                  const SizedBox(height: 16),

                  Text('¿A dónde te lo llevamos?', style: AppText.display(16)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _seatController,
                    focusNode: _seatFocus,
                    enabled: !_placing,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [LengthLimitingTextInputFormatter(60)],
                    decoration: const InputDecoration(
                      labelText: 'Tu asiento',
                      hintText: 'Sector B · Fila 12 · Asiento 7',
                      prefixIcon: Icon(Icons.event_seat),
                      helperText: 'Sé específico: el mesero te busca con esto.',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PosHint(message: _config.pickupHint),

                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    enabled: !_placing,
                    maxLines: 2,
                    inputFormatters: [LengthLimitingTextInputFormatter(200)],
                    decoration: const InputDecoration(
                      labelText: 'Nota para el negocio (opcional)',
                      hintText: 'Sin cebolla, por favor',
                      prefixIcon: Icon(Icons.edit_note),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _Summary(
                    subtotal: subtotal,
                    fee: fee,
                    feeLabel: _config.serviceFeeLabel,
                    total: total,
                    balance: balance,
                    rate: context.watch<RateService>().rate,
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
                      ),
                      child: Text(_error!, style: AppText.body(13)),
                    ),
                  ],
                ],
              ),
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : ReadableBar(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!affordable && balance.cardLinked)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Te faltan ${(total - balance.available).format()} disponibles.',
                          style: AppText.body(13, color: AppColors.warning),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ElevatedButton(
                      onPressed: canPlace ? _place : null,
                      child: _placing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.midnight,
                              ),
                            )
                          : Text('Enviar pedido · ${total.format()}'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'El cobro se hace cuando confirmes que recibiste tu pedido.',
                      style: AppText.body(11, color: AppColors.grayLight),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.subtotal,
    required this.fee,
    required this.total,
    required this.balance,
    this.feeLabel,
    this.rate,
  });

  final Money subtotal;
  final Money fee;
  final Money total;
  final Balance balance;
  final String? feeLabel;

  final double? rate;

  @override
  Widget build(BuildContext context) {
    final linked = balance.cardLinked;
    final totalHint = total.usdHint(rate);
    final after = linked ? balance.available - total : Money.zero;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _row('Productos', subtotal.format()),
          if (fee.isPositive) ...[
            const SizedBox(height: 8),
            _row(feeLabel ?? 'Servicio de entrega', fee.format()),
          ],
          const Divider(height: 20),
          _row('Total a pagar', total.format(), emphasise: true),
          if (totalHint.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Text(totalHint, style: AppText.body(11, color: AppColors.grayLight)),
            ),
          const SizedBox(height: 12),
          _row('Tu saldo', linked ? balance.available.format() : '—'),
          const Divider(height: 20),
          _row('Te queda', linked ? after.format() : '—'),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasise = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.body(13, color: AppColors.grayLight)),
          Text(value, style: AppText.figure(emphasise ? 18 : 14)),
        ],
      );
}

class _PosHint extends StatelessWidget {
  const _PosHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.midnight,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.contactless, size: 20, color: AppColors.skyDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Ya estás en el puesto?',
                  style: AppText.body(13, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(message, style: AppText.body(12, color: AppColors.grayLight)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
