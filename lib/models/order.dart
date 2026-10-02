import 'package:flutter/foundation.dart';

import '../utils/money.dart';

enum OrderStatus {
  pending,
  accepted,
  preparing,
  ready,
  inTransit,
  delivered,
  rejected,
  cancelled,
  paymentFailed,
  completed,
  unknown;

  static OrderStatus parse(String? raw) {
    switch (raw) {
      case 'pending':
        return OrderStatus.pending;
      case 'accepted':
        return OrderStatus.accepted;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'in_transit':
        return OrderStatus.inTransit;
      case 'delivered':
        return OrderStatus.delivered;
      case 'rejected':
        return OrderStatus.rejected;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'payment_failed':
        return OrderStatus.paymentFailed;
      case 'completed':
        return OrderStatus.completed;
      default:
        return OrderStatus.unknown;
    }
  }

  String get wire {
    switch (this) {
      case OrderStatus.inTransit:
        return 'in_transit';
      case OrderStatus.paymentFailed:
        return 'payment_failed';
      default:
        return name;
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Esperando al negocio';
      case OrderStatus.accepted:
        return 'Confirmado';
      case OrderStatus.preparing:
        return 'En preparación';
      case OrderStatus.ready:
        return 'Listo';
      case OrderStatus.inTransit:
        return 'En camino';
      case OrderStatus.delivered:
        return 'Entregado';
      case OrderStatus.rejected:
        return 'Rechazado';
      case OrderStatus.cancelled:
        return 'Cancelado';
      case OrderStatus.paymentFailed:
        return 'Cobro pendiente';
      case OrderStatus.completed:
        return 'Completado';
      case OrderStatus.unknown:
        return 'En proceso';
    }
  }

  String get detail {
    switch (this) {
      case OrderStatus.pending:
        return 'El negocio aún no confirma tu pedido. Si no responde en 10 minutos lo cancelamos y liberamos tu saldo.';
      case OrderStatus.accepted:
        return 'El negocio confirmó tu pedido y va a empezar a prepararlo.';
      case OrderStatus.preparing:
        return 'Están preparando tu pedido.';
      case OrderStatus.ready:
        return 'Tu pedido está listo. Un mesero lo va a recoger.';
      case OrderStatus.inTransit:
        return 'El mesero va hacia tu asiento. Cuando lo recibas, confirma aquí '
            'para completar el pedido.';
      case OrderStatus.delivered:
        return 'Entregado y pagado. ¡Buen provecho!';
      case OrderStatus.rejected:
        return 'El negocio no pudo tomar el pedido. Tu saldo quedó libre otra vez.';
      case OrderStatus.cancelled:
        return 'El pedido fue cancelado y tu saldo quedó libre.';
      case OrderStatus.paymentFailed:
        return 'El cobro no pasó. Recarga tu saldo y vuelve a confirmar, o pide '
            'al mesero que pase tu tarjeta.';
      case OrderStatus.completed:
        return 'Pedido completado.';
      case OrderStatus.unknown:
        return 'Tu pedido está en proceso.';
    }
  }

  bool get isOpen => const {
        OrderStatus.pending,
        OrderStatus.accepted,
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.inTransit,
        OrderStatus.paymentFailed,
      }.contains(this);

  bool get isFinished => !isOpen;

  bool get canCancel => this == OrderStatus.pending;

  bool get canConfirm =>
      this == OrderStatus.inTransit || this == OrderStatus.paymentFailed;

  int get railIndex {
    switch (this) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.accepted:
        return 1;
      case OrderStatus.preparing:
        return 2;
      case OrderStatus.ready:
        return 3;
      case OrderStatus.inTransit:
        return 4;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return 5;
      default:
        return -1;
    }
  }

  static const List<OrderStatus> rail = [
    OrderStatus.pending,
    OrderStatus.accepted,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.inTransit,
    OrderStatus.delivered,
  ];
}

@immutable
class OrderLine {
  const OrderLine({
    required this.name,
    required this.qty,
    required this.price,
    this.kind = 'item',
    this.productId,
  });

  final String name;
  final int qty;
  final Money price;
  final String kind;
  final int? productId;

  Money get lineTotal => price * qty;

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        name: (json['name'] as String?) ?? 'Producto',
        qty: json['qty'] as int? ?? 1,
        price: Money.parse(json['price']),
        kind: (json['kind'] as String?) ?? 'item',
        productId: json['product_id'] as int?,
      );
}

@immutable
class OrderEvent {
  const OrderEvent({required this.status, required this.at, this.note});

  final OrderStatus status;
  final DateTime at;
  final String? note;

  factory OrderEvent.fromJson(Map<String, dynamic> json) => OrderEvent(
        status: OrderStatus.parse(json['status'] as String?),
        at: DateTime.tryParse('${json['created_at']}')?.toLocal() ?? DateTime.now(),
        note: json['note'] as String?,
      );
}

@immutable
class Cancellation {
  const Cancellation({
    required this.status,
    required this.byShop,
    this.shopMessage,
    this.note,
    this.at,
  });

  final OrderStatus status;

  final bool byShop;

  final String? shopMessage;

  final String? note;

  final DateTime? at;

  bool get hasShopMessage =>
      shopMessage != null && shopMessage!.trim().isNotEmpty;

  factory Cancellation.fromJson(Map<String, dynamic> json) => Cancellation(
        status: OrderStatus.parse(json['status'] as String?),
        byShop: (json['by'] as String?) == 'shop',
        shopMessage: (json['shop_message'] as String?)?.trim(),
        note: (json['note'] as String?)?.trim(),
        at: DateTime.tryParse('${json['at']}')?.toLocal(),
      );
}

@immutable
class Order {
  const Order({
    required this.id,
    required this.code,
    required this.shopId,
    required this.shopName,
    required this.status,
    required this.total,
    required this.createdAt,
    this.subtotal = Money.zero,
    this.serviceFee = Money.zero,
    this.currency = 'USD',
    this.fulfillment = 'seat',
    this.seatLabel,
    this.customerNote,
    this.logoUrl,
    this.lines = const [],
    this.timeline = const [],
    this.cancellation,
    this.listShopMessage,
  });

  final int id;

  final String code;

  final int shopId;
  final String shopName;
  final OrderStatus status;
  final Money total;

  final DateTime createdAt;

  final Money subtotal;

  final Money serviceFee;

  final String currency;
  final String fulfillment;
  final String? seatLabel;
  final String? customerNote;
  final String? logoUrl;
  final List<OrderLine> lines;
  final List<OrderEvent> timeline;

  final Cancellation? cancellation;

  final String? listShopMessage;

  String? get shopMessage => cancellation?.shopMessage ?? listShopMessage;
  bool get hasShopMessage =>
      shopMessage != null && shopMessage!.trim().isNotEmpty;

  bool get isSeatDelivery => fulfillment == 'seat';
  bool get hasServiceFee => serviceFee.isPositive;

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as int,
        code: (json['order_code'] as String?) ?? '—',
        shopId: json['shop_id'] as int? ?? 0,
        shopName: (json['shop_name'] as String?) ?? 'Negocio',
        status: OrderStatus.parse(json['status'] as String?),
        total: Money.parse(json['total']),
        subtotal: Money.parse(json['subtotal'] ?? json['total']),
        serviceFee: Money.parse(json['service_fee']),
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal() ?? DateTime.now(),
        currency: (json['currency'] as String?) ?? 'USD',
        fulfillment: (json['fulfillment'] as String?) ?? 'seat',
        seatLabel: json['seat_label'] as String?,
        customerNote: json['customer_note'] as String?,
        logoUrl: json['logo_url'] as String?,
        lines: (json['items'] as List<dynamic>? ?? [])
            .map((e) => OrderLine.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        timeline: (json['timeline'] as List<dynamic>? ?? [])
            .map((e) => OrderEvent.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        listShopMessage: (json['shop_message'] as String?)?.trim(),
        cancellation: json['cancellation'] == null
            ? null
            : Cancellation.fromJson(json['cancellation'] as Map<String, dynamic>),
      );
}
