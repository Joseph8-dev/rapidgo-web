import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/api_config.dart';
import '../utils/money.dart';
import 'api_service.dart';

@immutable
class Bank {
  const Bank({required this.code, required this.name});

  final String code;
  final String name;

  factory Bank.fromJson(Map<String, dynamic> j) =>
      Bank(code: j['code'] as String, name: j['name'] as String);
}

@immutable
class WithdrawalConfig {
  const WithdrawalConfig({
    this.enabled = false,
    this.min = Money.zero,
    this.max = Money.zero,
    this.dailyMax = Money.zero,
    this.feePct = 0,
    this.feeFlat = Money.zero,
    this.withdrawnToday = Money.zero,
    this.available = Money.zero,
    this.banks = const [],
    this.benefIdent = '',
    this.benefIdentDisplay = '',
    this.suggestedName = '',
  });

  final bool enabled;
  final Money min;
  final Money max;
  final Money dailyMax;
  final double feePct;
  final Money feeFlat;
  final Money withdrawnToday;
  final Money available;
  final List<Bank> banks;

  final String benefIdent;

  final String benefIdentDisplay;

  final String suggestedName;

  Money feeFor(Money amount) {
    if (amount.cents <= 0) return Money.zero;
    final pct = feePct > 0 ? ((amount.cents * feePct) / 100).round() : 0;
    return Money(pct + feeFlat.cents);
  }

  Money totalFor(Money amount) => amount + feeFor(amount);

  Money get ceiling {
    final remainingToday = Money(dailyMax.cents - withdrawnToday.cents);
    var limit = available;
    if (max < limit) limit = max;
    if (remainingToday < limit) limit = remainingToday;
    return limit.cents < 0 ? Money.zero : limit;
  }

  factory WithdrawalConfig.fromJson(Map<String, dynamic> j) => WithdrawalConfig(
        enabled: j['enabled'] as bool? ?? false,
        min: Money.parse(j['min']),
        max: Money.parse(j['max']),
        dailyMax: Money.parse(j['daily_max']),
        feePct: (j['fee_pct'] as num?)?.toDouble() ?? 0,
        feeFlat: Money.parse(j['fee_flat']),
        withdrawnToday: Money.parse(j['withdrawn_today']),
        available: Money.parse(j['available']),
        banks: (j['banks'] as List<dynamic>? ?? [])
            .map((e) => Bank.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        benefIdent: (j['benef_ident'] as String?) ?? '',
        benefIdentDisplay: (j['benef_ident_display'] as String?) ?? '',
        suggestedName: (j['suggested_name'] as String?) ?? '',
      );
}

@immutable
class SavedAccount {
  const SavedAccount({
    required this.id,
    required this.payType,
    required this.bankCode,
    required this.bankName,
    required this.benefNames,
    required this.destinationMasked,
    this.alias,
  });

  final int id;
  final String payType;
  final String bankCode;
  final String bankName;
  final String benefNames;
  final String destinationMasked;
  final String? alias;

  bool get isPagoMovil => payType == 'PMV';
  String get label => alias?.isNotEmpty == true ? alias! : bankName;

  factory SavedAccount.fromJson(Map<String, dynamic> j) => SavedAccount(
        id: j['id'] as int,
        payType: (j['pay_type'] as String?) ?? 'PMV',
        bankCode: (j['bank_code'] as String?) ?? '',
        bankName: (j['bank_name'] as String?) ?? '',
        benefNames: (j['benef_names'] as String?) ?? '',
        destinationMasked: (j['destination_masked'] as String?) ?? '****',
        alias: j['alias'] as String?,
      );
}

enum WithdrawalStatus {
  created, sent, paid, cancelled, failedValidation, unknown, needsReview;

  static WithdrawalStatus parse(String? raw) {
    switch (raw) {
      case 'paid': return WithdrawalStatus.paid;
      case 'sent': return WithdrawalStatus.sent;
      case 'cancelled': return WithdrawalStatus.cancelled;
      case 'failed_validation': return WithdrawalStatus.failedValidation;
      case 'unknown': return WithdrawalStatus.unknown;
      case 'needs_review': return WithdrawalStatus.needsReview;
      default: return WithdrawalStatus.created;
    }
  }

  String get label {
    switch (this) {
      case WithdrawalStatus.created:
      case WithdrawalStatus.sent:
        return 'En proceso';
      case WithdrawalStatus.paid:
        return 'Transferido';
      case WithdrawalStatus.cancelled:
        return 'Devuelto a tu saldo';
      case WithdrawalStatus.failedValidation:
        return 'Rechazado';
      case WithdrawalStatus.unknown:
      case WithdrawalStatus.needsReview:
        return 'En revisión';
    }
  }

  String get detail {
    switch (this) {
      case WithdrawalStatus.created:
      case WithdrawalStatus.sent:
        return 'El banco está procesando la transferencia. Suele tardar entre 3 y 15 minutos.';
      case WithdrawalStatus.paid:
        return 'El dinero llegó a tu cuenta.';
      case WithdrawalStatus.cancelled:
        return 'El banco no pudo completar la transferencia. Te devolvimos el monto completo a tu saldo.';
      case WithdrawalStatus.failedValidation:
        return 'Los datos de la cuenta fueron rechazados. No se te descontó nada.';
      case WithdrawalStatus.unknown:
      case WithdrawalStatus.needsReview:
        return 'Estamos confirmando esta operación con el banco. Si necesitas ayuda, acude a taquilla con esta referencia.';
    }
  }

  bool get isOpen =>
      this == WithdrawalStatus.created ||
      this == WithdrawalStatus.sent ||
      this == WithdrawalStatus.unknown;

  bool get isRefunded =>
      this == WithdrawalStatus.cancelled ||
      this == WithdrawalStatus.failedValidation;
}

@immutable
class Withdrawal {
  const Withdrawal({
    required this.id,
    required this.amount,
    required this.fee,
    required this.total,
    required this.status,
    required this.createdAt,
    this.bankName = '',
    this.payType = 'PMV',
    this.destinationMasked = '****',
    this.benefNames = '',
    this.bankReference,
    this.note,
  });

  final int id;
  final Money amount;
  final Money fee;
  final Money total;
  final WithdrawalStatus status;
  final DateTime createdAt;
  final String bankName;
  final String payType;
  final String destinationMasked;
  final String benefNames;

  final String? bankReference;

  final String? note;

  factory Withdrawal.fromJson(Map<String, dynamic> j) => Withdrawal(
        id: j['id'] as int,
        amount: Money.parse(j['amount']),
        fee: Money.parse(j['fee']),
        total: Money.parse(j['total']),
        status: WithdrawalStatus.parse(j['status'] as String?),
        createdAt: DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
        bankName: (j['bank_name'] as String?) ?? '',
        payType: (j['pay_type'] as String?) ?? 'PMV',
        destinationMasked: (j['destination_masked'] as String?) ?? '****',
        benefNames: (j['benef_names'] as String?) ?? '',
        bankReference: j['bank_reference'] as String?,
        note: j['note'] as String?,
      );
}

class WithdrawalService {
  WithdrawalService(this._api);

  final ApiService _api;

  Future<WithdrawalConfig> config() async =>
      WithdrawalConfig.fromJson(await _api.get(ApiConfig.withdrawConfig));

  Future<List<SavedAccount>> accounts() async {
    final res = await _api.get(ApiConfig.withdrawAccounts);
    return (res['accounts'] as List<dynamic>? ?? [])
        .map((e) => SavedAccount.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<int> addAccount({
    required String payType,
    required String bankCode,
    required String benefNames,
    String? phoneNumber,
    String? accountNumber,
    String? alias,
  }) async {
    final res = await _api.post(ApiConfig.withdrawAccounts, body: {
      'pay_type': payType,
      'bank_code': bankCode,
      'benef_names': benefNames,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (accountNumber != null) 'account_number': accountNumber,
      if (alias != null && alias.isNotEmpty) 'alias': alias,
    });
    return res['id'] as int;
  }

  Future<void> removeAccount(int id) =>
      _api.delete('${ApiConfig.withdrawAccounts}/$id');

  Future<Withdrawal> request({
    required Money amount,
    required String password,
    required String idempotencyKey,
    int? accountId,
    String? payType,
    String? bankCode,
    String? benefNames,
    String? phoneNumber,
    String? accountNumber,
  }) async {
    final res = await _api.post(ApiConfig.withdrawals, body: {
      'amount': amount.toWire(),
      'password': password,
      'idempotency_key': idempotencyKey,
      if (accountId != null) 'account_id': accountId,
      if (accountId == null) ...{
        'pay_type': payType,
        'bank_code': bankCode,
        'benef_names': benefNames,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (accountNumber != null) 'account_number': accountNumber,
      },
    });
    return Withdrawal.fromJson(res['withdrawal'] as Map<String, dynamic>);
  }

  Future<List<Withdrawal>> history() async {
    final res = await _api.get(ApiConfig.withdrawals);
    return (res['withdrawals'] as List<dynamic>? ?? [])
        .map((e) => Withdrawal.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Withdrawal> byId(int id) async =>
      Withdrawal.fromJson(await _api.get('${ApiConfig.withdrawals}/$id'));

  static String newIdempotencyKey() => const Uuid().v4();
}
