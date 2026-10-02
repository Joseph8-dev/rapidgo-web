import '../config/api_config.dart';
import '../utils/money.dart';
import 'api_service.dart';

class RapidGoConfig {
  const RapidGoConfig({
    this.serviceFeePct = 0,
    this.serviceFeeMin = Money.zero,
    this.serviceFeeMax,
    this.serviceFeeLabel,
    this.pickupHint = _defaultPickupHint,
    this.holdTtlMinutes = 90,
    this.maxOpenOrders = 3,
    this.usdVesRate,
    this.maxOrderTotal = const Money(50000),
  });

  static const String _defaultPickupHint =
      'RapidGo te lleva el pedido al asiento. Si ya estás en el puesto, paga '
      'directo con tu tarjeta en el punto de venta: es inmediato y sin costo '
      'de servicio.';

  final double serviceFeePct;
  final Money serviceFeeMin;
  final Money? serviceFeeMax;
  final String? serviceFeeLabel;
  final String pickupHint;
  final int holdTtlMinutes;

  final int maxOpenOrders;

  final double? usdVesRate;
  final Money maxOrderTotal;

  bool get hasFee => serviceFeePct > 0;

  static const RapidGoConfig fallback = RapidGoConfig();

  Money feeFor(Money subtotal) {
    if (serviceFeePct <= 0 || subtotal.cents <= 0) return Money.zero;

    var cents = ((subtotal.cents * serviceFeePct) / 100).round();
    if (serviceFeeMin.cents > 0 && cents < serviceFeeMin.cents) {
      cents = serviceFeeMin.cents;
    }
    final max = serviceFeeMax;
    if (max != null && cents > max.cents) cents = max.cents;
    if (cents > subtotal.cents) cents = subtotal.cents;
    return Money(cents);
  }

  Money totalFor(Money subtotal) => subtotal + feeFor(subtotal);

  factory RapidGoConfig.fromJson(Map<String, dynamic> json) => RapidGoConfig(
        serviceFeePct: (json['service_fee_pct'] as num?)?.toDouble() ?? 0,
        serviceFeeMin: Money.parse(json['service_fee_min']),
        serviceFeeMax: json['service_fee_max'] == null
            ? null
            : Money.parse(json['service_fee_max']),
        serviceFeeLabel: json['service_fee_label'] as String?,
        pickupHint: (json['pickup_hint'] as String?) ?? _defaultPickupHint,
        holdTtlMinutes: json['hold_ttl_minutes'] as int? ?? 90,
        maxOpenOrders: json['max_open_orders'] as int? ?? 3,
        usdVesRate: (json['usd_ves_rate'] as num?)?.toDouble(),
        maxOrderTotal: Money.parse(json['max_order_total']),
      );
}

class ConfigService {
  ConfigService(this._api);

  final ApiService _api;

  RapidGoConfig _config = RapidGoConfig.fallback;
  bool _loaded = false;
  Future<RapidGoConfig>? _inFlight;

  RapidGoConfig get current => _config;
  bool get isLoaded => _loaded;

  Future<RapidGoConfig> load({bool force = false}) {
    if (_loaded && !force) return Future.value(_config);
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  Future<RapidGoConfig> _fetch() async {
    try {
      _config = RapidGoConfig.fromJson(await _api.get(ApiConfig.config));
      _loaded = true;
    } on ApiException {
    }
    return _config;
  }
}
