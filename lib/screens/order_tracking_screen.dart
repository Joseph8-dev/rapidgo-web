import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/order.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/rate_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/app_widgets.dart';
import '../widgets/responsive.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late final OrderTracker _tracker;
  OrderStatus? _lastStatus;
  bool _cancelling = false;
  bool _confirming = false;

  late final String _confirmKey = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _tracker = OrderTracker(
      service: context.read<OrderService>(),
      orderId: widget.orderId,
    )..addListener(_onUpdate);
    unawaited(_tracker.start());
  }

  @override
  void dispose() {
    _tracker.removeListener(_onUpdate);
    _tracker.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (!mounted) return;
    final status = _tracker.order?.status;
    if (status != null && status != _lastStatus) {
      if (_lastStatus != null) HapticFeedback.mediumImpact();
      _lastStatus = status;

      if (status.isFinished) unawaited(context.read<AuthService>().refreshBalance());
    }
    setState(() {});
  }

  Future<void> _confirm() async {
    final order = _tracker.order;
    if (order == null || _confirming) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDialogStyle.background,
        shape: AppDialogStyle.shape,
        title: const Text('¿Recibiste tu pedido?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Al confirmar se cobra de tu saldo:',
              style: AppText.body(14, color: AppColors.grayLight),
            ),
            const SizedBox(height: 12),
            Center(child: Text(order.total.bs(), style: AppText.figure(30))),
            const SizedBox(height: 12),
            Text(
              '${order.shopName} · Pedido ${order.code}',
              style: AppText.body(13, color: AppColors.grayLight),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Confirma sólo cuando tengas el pedido contigo. '
                    'El cobro no se puede deshacer.',
                    style: AppText.body(12, color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Todavía no'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, lo recibí'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _confirming = true);
    try {
      await context.read<OrderService>().confirmDelivery(widget.orderId, _confirmKey);
      if (!mounted) return;
      await _tracker.refresh();
      if (!mounted) return;
      unawaited(context.read<AuthService>().refreshBalance());
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Listo! Pedido completado. Buen provecho.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_explainConfirm(e)), duration: const Duration(seconds: 6)),
      );
      await _tracker.refresh();
      if (mounted) unawaited(context.read<AuthService>().refreshBalance());
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  String _explainConfirm(ApiException e) {
    switch (e.code) {
      case 'insufficient_funds':
      case 'no_card_linked':
      case 'card_inactive':
        return e.message;
      case 'invalid_transition':
        return 'Este pedido ya no se puede confirmar. Revisa su estado.';
      default:
        return e.message;
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDialogStyle.background,
        shape: AppDialogStyle.shape,
        title: const Text('¿Cancelar el pedido?'),
        content: const Text('El monto vuelve a tu saldo. Sólo se puede antes de que el negocio confirme el pedido.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await context.read<OrderService>().cancel(widget.orderId);
      if (!mounted) return;
      await _tracker.refresh();
      if (mounted) await context.read<AuthService>().refreshBalance();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      await _tracker.refresh();
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _tracker.order;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu pedido'),
        actions: [
          IconButton(
            onPressed: () => unawaited(_tracker.refresh()),
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: ReadableSafeArea(
        child: order == null
            ? _tracker.isLoading
                ? const Center(child: CircularProgressIndicator())
                : EmptyState(
                    icon: Icons.error_outline,
                    title: 'No pudimos cargar el pedido',
                    message: '${_tracker.error ?? ''}',
                    action: ElevatedButton(
                      onPressed: () => unawaited(_tracker.refresh()),
                      child: const Text('Reintentar'),
                    ),
                  )
            : RefreshIndicator(
                onRefresh: _tracker.refresh,
                color: AppColors.skyLight,
                backgroundColor: AppColors.surface,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (order.cancellation != null) ...[
                      _CancellationCard(
                        cancellation: order.cancellation!,
                        shopName: order.shopName,
                        refunded: order.total,
                      ),
                      const SizedBox(height: 20),
                      _CodeCard(order: order),
                    ] else ...[
                      _CodeCard(order: order),
                      const SizedBox(height: 20),
                      OrderStatusRail(status: order.status),
                      const SizedBox(height: 16),
                      Text(order.status.label, style: AppText.display(22)),
                      const SizedBox(height: 6),
                      Text(order.status.detail,
                          style: AppText.body(14, color: AppColors.grayLight)),
                    ],
                    if (!_tracker.isPolling && order.status.isOpen) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Dejamos de actualizar solo. Desliza para refrescar.',
                        style: AppText.body(12, color: AppColors.warning),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _Items(order: order),
                    if (order.timeline.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('Historial', style: AppText.display(16)),
                      const SizedBox(height: 10),
                      ...order.timeline.map((e) => _TimelineRow(event: e)),
                    ],
                  ],
                ),
              ),
      ),
      bottomNavigationBar: order == null
          ? null
          : order.status.canConfirm
              ? ReadableBar(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _confirming ? null : _confirm,
                          icon: _confirming
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.midnight),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text('Pedido completado · ${order.total.bs()}'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Confirma cuando tengas tu pedido. Si prefieres, el mesero '
                          'puede pasar tu tarjeta.',
                          style: AppText.body(11, color: AppColors.grayLight),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : order.status.canCancel
                  ? ReadableBar(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton(
                          onPressed: _cancelling ? null : _cancel,
                          child: _cancelling
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Cancelar pedido'),
                        ),
                      ),
                    )
                  : null,
    );
  }
}

class _CancellationCard extends StatelessWidget {
  const _CancellationCard({
    required this.cancellation,
    required this.shopName,
    required this.refunded,
  });

  final Cancellation cancellation;
  final String shopName;
  final Money refunded;

  @override
  Widget build(BuildContext context) {
    final byShop = cancellation.byShop;

    final headline = byShop
        ? '$shopName no pudo preparar tu pedido.'
        : cancellation.status == OrderStatus.cancelled
            ? 'Tu pedido fue cancelado.'
            : 'El pedido no se pudo completar.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cancel_outlined, color: AppColors.danger),
              const SizedBox(width: 10),
              Text('Pedido cancelado', style: AppText.display(20)),
            ],
          ),
          const SizedBox(height: 12),
          Text(headline, style: AppText.body(15)),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No se te cobró nada. Los ${refunded.format()} ya están '
                  'disponibles otra vez.',
                  style: AppText.body(14, color: AppColors.success),
                ),
              ),
            ],
          ),

          if (cancellation.hasShopMessage) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.midnight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shopName,
                    style: AppText.body(11, color: AppColors.skyDeep, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '“${cancellation.shopMessage}”',
                    style: AppText.body(14, color: AppColors.grayLight),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context)
                  .popUntil((route) => route.isFirst),
              icon: const Icon(Icons.storefront),
              label: const Text('Pedir en otro negocio'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.midnight,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text('Tu código', style: AppText.body(12, color: AppColors.grayLight)),
          const SizedBox(height: 4),
          Text(order.code, style: AppText.display(52, color: AppColors.skyLight)),
          const SizedBox(height: 10),
          Text(order.shopName, style: AppText.body(15, weight: FontWeight.w600)),
          if (order.isSeatDelivery && order.seatLabel != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_seat, size: 15, color: AppColors.skyDeep),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(order.seatLabel!,
                      style: AppText.body(13, color: AppColors.grayLight)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Items extends StatelessWidget {
  const _Items({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ...order.lines.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text('${l.qty}×', style: AppText.figure(14)),
                    ),
                    Expanded(child: Text(l.name, style: AppText.body(14))),
                    Text(l.lineTotal.format(), style: AppText.figure(14)),
                  ],
                ),
              )),
          if (order.customerNote != null && order.customerNote!.isNotEmpty) ...[
            const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.edit_note, size: 16, color: AppColors.grayLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(order.customerNote!,
                      style: AppText.body(13, color: AppColors.grayLight)),
                ),
              ],
            ),
          ],
          const Divider(height: 24),
          if (order.hasServiceFee) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Productos', style: AppText.body(13, color: AppColors.grayLight)),
                Text(order.subtotal.format(), style: AppText.figure(14)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Servicio de entrega',
                    style: AppText.body(13, color: AppColors.grayLight)),
                Text(order.serviceFee.format(), style: AppText.figure(14)),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.status == OrderStatus.delivered ? 'Cobrado' : 'Total',
                style: AppText.body(13, color: AppColors.grayLight),
              ),
              Text(order.total.format(), style: AppText.figure(20)),
            ],
          ),
          Builder(builder: (context) {
            final hint = order.total.usdHint(context.watch<RateService>().rate);
            if (hint.isEmpty) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.centerRight,
              child: Text(hint, style: AppText.body(11, color: AppColors.grayLight)),
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event});

  final OrderEvent event;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(event.at).format(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.forStatus(event.status.wire),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.status.label, style: AppText.body(14)),
                if (event.note != null && event.note!.isNotEmpty)
                  Text(event.note!, style: AppText.body(12, color: AppColors.grayLight)),
              ],
            ),
          ),
          Text(time, style: AppText.body(12, color: AppColors.grayLight)),
        ],
      ),
    );
  }
}
