import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../services/api_service.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/responsive.dart';
import 'order_tracking_screen.dart';

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  List<Order> _orders = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final orders = await context.read<OrderService>().list(limit: 30);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_orders.isEmpty) _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = _orders.where((o) => o.status.isOpen).toList(growable: false);
    final past = _orders.where((o) => o.status.isFinished).toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis pedidos')),
      body: ReadableSafeArea(child: _body(open, past)),
    );
  }

  Widget _body(List<Order> open, List<Order> past) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null && _orders.isEmpty) {
      return EmptyState(
        icon: Icons.wifi_off,
        title: 'No pudimos cargar tus pedidos',
        message: _error!,
        action: ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
      );
    }

    if (_orders.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long,
        title: 'Aún no has pedido nada',
        message: 'Cuando hagas tu primer pedido aparecerá aquí.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.skyLight,
      backgroundColor: AppColors.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (open.isNotEmpty) ...[
            Text('En curso', style: AppText.display(18)),
            const SizedBox(height: 10),
            ...open.map((o) => _OrderRow(order: o, onTap: () => _open(o))),
            const SizedBox(height: 20),
          ],
          if (past.isNotEmpty) ...[
            Text('Anteriores', style: AppText.display(18)),
            const SizedBox(height: 10),
            ...past.map((o) => _OrderRow(order: o, onTap: () => _open(o))),
          ],
        ],
      ),
    );
  }

  Future<void> _open(Order order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: order.id)),
    );
    if (mounted) unawaited(_load());
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(order.status.wire);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.midnight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text(order.code, style: AppText.display(18, color: color)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.shopName,
                      style: AppText.body(15, weight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(order.status.label, style: AppText.body(12, color: color)),
                    Text(
                      _when(order.createdAt),
                      style: AppText.body(11, color: AppColors.grayLight),
                    ),
                    if (order.hasShopMessage) ...[
                      const SizedBox(height: 4),
                      Text(
                        '“${order.shopMessage}”',
                        style: AppText.body(11, color: AppColors.grayLight),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Text(order.total.format(), style: AppText.figure(15)),
            ],
          ),
        ),
      ),
    );
  }

  String _when(DateTime at) {
    final now = DateTime.now();
    final sameDay = at.year == now.year && at.month == now.month && at.day == now.day;
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    if (sameDay) return 'Hoy $hh:$mm';
    return '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')} $hh:$mm';
  }
}
