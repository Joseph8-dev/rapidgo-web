import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/rate_service.dart';
import '../services/withdrawal_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/app_widgets.dart';
import '../widgets/responsive.dart';
import 'withdraw_confirm_screen.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _accountController = TextEditingController();
  final _amountFocus = FocusNode();

  WithdrawalConfig? _config;
  List<SavedAccount> _accounts = const [];
  bool _loading = true;
  String? _error;

  SavedAccount? _selected;
  bool _newDestination = true;
  String _payType = 'PMV';
  String? _bankCode;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _accountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final service = context.read<WithdrawalService>();
    try {
      final config = await service.config();
      final accounts = await service.accounts();
      if (!mounted) return;
      setState(() {
        _config = config;
        _accounts = accounts;
        _newDestination = accounts.isEmpty;
        _selected = accounts.isNotEmpty ? accounts.first : null;
        if (_nameController.text.isEmpty) _nameController.text = config.suggestedName;
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

  Money get _amount => Money.parseInput(_amountController.text) ?? Money.zero;

  String? _validateAmount(WithdrawalConfig config) {
    final amount = _amount;
    if (amount.cents <= 0) return 'Escribe cuánto quieres retirar.';
    if (amount < config.min) return 'El mínimo es ${config.min.bs()}.';
    if (amount > config.max) return 'El máximo por retiro es ${config.max.bs()}.';

    final total = config.totalFor(amount);
    if (total > config.available) {
      return 'No tienes saldo disponible suficiente. Disponible: ${config.available.bs()}.';
    }
    final remainingToday = Money(config.dailyMax.cents - config.withdrawnToday.cents);
    if (total > remainingToday) {
      return 'Hoy te queda ${remainingToday.bs()} por retirar.';
    }
    return null;
  }

  void _continue() {
    final config = _config;
    if (config == null) return;
    FocusScope.of(context).unfocus();

    final amountError = _validateAmount(config);
    if (amountError != null) {
      setState(() => _error = amountError);
      _amountFocus.requestFocus();
      return;
    }
    if (!_newDestination && _selected == null) {
      setState(() => _error = 'Elige una cuenta.');
      return;
    }
    if (_newDestination && !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _error = null);

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WithdrawConfirmScreen(
        amount: _amount,
        config: config,
        savedAccount: _newDestination ? null : _selected,
        payType: _payType,
        bankCode: _bankCode,
        benefNames: _nameController.text.trim(),
        phoneNumber: _phoneController.text.replaceAll(RegExp(r'\D'), ''),
        accountNumber: _accountController.text.replaceAll(RegExp(r'\D'), ''),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Retirar saldo')),
      body: ReadableSafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final config = _config;
    if (config == null) {
      return EmptyState(
        icon: Icons.wifi_off,
        title: 'No pudimos cargar los retiros',
        message: _error ?? '',
        action: ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
      );
    }
    if (!config.enabled) {
      return const EmptyState(
        icon: Icons.account_balance,
        title: 'Retiros no disponibles',
        message: 'En este momento no se pueden procesar retiros. Intenta más tarde '
            'o acude a taquilla.',
      );
    }

    final rate = context.watch<RateService>().rate;
    final amount = _amount;
    final fee = config.feeFor(amount);
    final total = config.totalFor(amount);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _AvailableCard(config: config, rate: rate),
          const SizedBox(height: 18),

          Text('¿Cuánto quieres retirar?', style: AppText.display(16)),
          const SizedBox(height: 10),
          TextFormField(
            controller: _amountController,
            focusNode: _amountFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              LengthLimitingTextInputFormatter(15),
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Monto en bolívares',
              prefixText: 'Bs ',
              helperText: 'Entre ${config.min.bs()} y ${config.ceiling.bs()}',
              helperMaxLines: 2,
            ),
          ),
          if (amount.isPositive) ...[
            const SizedBox(height: 10),
            _TotalBreakdown(amount: amount, fee: fee, total: total, rate: rate),
          ],

          const SizedBox(height: 22),
          Text('Titular', style: AppText.display(16)),
          const SizedBox(height: 10),
          _LockedIdentField(config: config),

          const SizedBox(height: 22),
          Text('¿A qué cuenta?', style: AppText.display(16)),
          const SizedBox(height: 10),

          if (_accounts.isNotEmpty) ...[
            ..._accounts.map((a) => RadioListTile<SavedAccount>(
                  value: a,
                  groupValue: _newDestination ? null : _selected,
                  onChanged: (v) => setState(() {
                    _selected = v;
                    _newDestination = false;
                  }),
                  activeColor: AppColors.skyLight,
                  contentPadding: EdgeInsets.zero,
                  title: Text(a.label, style: AppText.body(14, weight: FontWeight.w600)),
                  subtitle: Text(
                    '${a.isPagoMovil ? 'Pago Móvil' : 'Transferencia'} · ${a.destinationMasked}',
                    style: AppText.body(12, color: AppColors.grayLight),
                  ),
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Eliminar',
                    onPressed: () => unawaited(_removeAccount(a)),
                  ),
                )),
            RadioListTile<bool>(
              value: true,
              groupValue: _newDestination,
              onChanged: (_) => setState(() => _newDestination = true),
              activeColor: AppColors.skyLight,
              contentPadding: EdgeInsets.zero,
              title: Text('Otra cuenta', style: AppText.body(14, weight: FontWeight.w600)),
            ),
          ],

          if (_newDestination) _destinationForm(config),

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

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: amount.isPositive ? _continue : null,
            child: const Text('Continuar'),
          ),
          const SizedBox(height: 10),
          Text(
            'Vas a poder revisar todo antes de confirmar.',
            style: AppText.body(11, color: AppColors.grayLight),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _destinationForm(WithdrawalConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'PMV', icon: Icon(Icons.phone_iphone), label: Text('Pago Móvil')),
            ButtonSegment(value: 'TRF', icon: Icon(Icons.account_balance), label: Text('Transferencia')),
          ],
          selected: {_payType},
          onSelectionChanged: (s) => setState(() => _payType = s.first),
        ),
        const SizedBox(height: 14),

        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [
            LengthLimitingTextInputFormatter(50),
            FilteringTextInputFormatter.allow(RegExp(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ' .]")),
          ],
          decoration: const InputDecoration(
            labelText: 'Nombre del titular',
            prefixIcon: Icon(Icons.person_outline),
            helperText: 'Como aparece en el banco',
          ),
          validator: (v) {
            final s = (v ?? '').trim();
            if (s.length < 6) return 'Escribe el nombre completo (mínimo 6 caracteres)';
            if (s.length > 50) return 'Máximo 50 caracteres';
            return null;
          },
        ),
        const SizedBox(height: 14),

        DropdownButtonFormField<String>(
          value: _bankCode,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Banco',
            prefixIcon: Icon(Icons.account_balance_outlined),
          ),
          items: config.banks
              .map((b) => DropdownMenuItem(
                    value: b.code,
                    child: Text('${b.code} · ${b.name}', overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _bankCode = v),
          validator: (v) => v == null ? 'Elige el banco' : null,
        ),
        const SizedBox(height: 14),

        if (_payType == 'PMV')
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            decoration: const InputDecoration(
              labelText: 'Teléfono del Pago Móvil',
              hintText: '04241234567',
              prefixIcon: Icon(Icons.phone_iphone),
              helperText: '11 dígitos: 0412, 0422, 0414, 0424, 0416 o 0426',
              helperMaxLines: 2,
            ),
            validator: (v) {
              final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
              if (d.length != 11) return 'El teléfono debe tener 11 dígitos';
              const prefixes = ['0412', '0422', '0414', '0424', '0416', '0426'];
              if (!prefixes.contains(d.substring(0, 4))) {
                return 'Debe empezar en ${prefixes.join(', ')}';
              }
              return null;
            },
          )
        else
          TextFormField(
            controller: _accountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(20),
            ],
            onChanged: (v) {
              final d = v.replaceAll(RegExp(r'\D'), '');
              if (d.length >= 4) {
                final derived = d.substring(0, 4);
                if (config.banks.any((b) => b.code == derived) && derived != _bankCode) {
                  setState(() => _bankCode = derived);
                }
              }
            },
            decoration: const InputDecoration(
              labelText: 'Número de cuenta',
              hintText: '01340123456789012345',
              prefixIcon: Icon(Icons.numbers),
              helperText: '20 dígitos. El banco se completa solo.',
              helperMaxLines: 2,
            ),
            validator: (v) {
              final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
              if (d.length != 20) return 'La cuenta debe tener exactamente 20 dígitos';
              if (!d.startsWith('01')) return 'La cuenta debe empezar con 01';
              if (_bankCode != null && d.substring(0, 4) != _bankCode) {
                return 'Esa cuenta no corresponde al banco seleccionado';
              }
              return null;
            },
          ),
      ],
    );
  }

  Future<void> _removeAccount(SavedAccount a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDialogStyle.background,
        shape: AppDialogStyle.shape,
        title: const Text('¿Eliminar esta cuenta?'),
        content: Text('${a.bankName} · ${a.destinationMasked}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<WithdrawalService>().removeAccount(a.id);
      if (mounted) unawaited(_load());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }
}

class _AvailableCard extends StatelessWidget {
  const _AvailableCard({required this.config, this.rate});

  final WithdrawalConfig config;
  final double? rate;

  @override
  Widget build(BuildContext context) {
    final hint = config.available.usdHint(rate);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.midnight,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text('Disponible para retirar',
              style: AppText.body(12, color: AppColors.grayLight)),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(config.available.bs(), style: AppText.figure(32)),
          ),
          if (hint.isNotEmpty)
            Text(hint, style: AppText.body(12, color: AppColors.grayLight)),
          if (config.withdrawnToday.isPositive) ...[
            const SizedBox(height: 8),
            Text(
              'Hoy ya retiraste ${config.withdrawnToday.bs()} de ${config.dailyMax.bs()}',
              style: AppText.body(11, color: AppColors.warning),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalBreakdown extends StatelessWidget {
  const _TotalBreakdown({
    required this.amount,
    required this.fee,
    required this.total,
    this.rate,
  });

  final Money amount;
  final Money fee;
  final Money total;
  final double? rate;

  @override
  Widget build(BuildContext context) {
    if (!fee.isPositive) return const SizedBox.shrink();
    final hint = total.usdHint(rate);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _row('Recibes', amount.bs()),
          const SizedBox(height: 6),
          _row('Comisión', fee.bs()),
          const Divider(height: 16),
          _row('Se descuenta de tu saldo', total.bs(), bold: true),
          if (hint.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Text(hint, style: AppText.body(10, color: AppColors.grayLight)),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.body(12, color: AppColors.grayLight)),
          Text(value, style: AppText.figure(bold ? 15 : 13)),
        ],
      );
}

class _LockedIdentField extends StatelessWidget {
  const _LockedIdentField({required this.config});

  final WithdrawalConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.midnight,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 18, color: AppColors.skyDeep),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cédula', style: AppText.body(11, color: AppColors.grayLight)),
                    const SizedBox(height: 2),
                    Text(
                      config.benefIdentDisplay.isNotEmpty
                          ? config.benefIdentDisplay
                          : config.benefIdent,
                      style: AppText.figure(17, color: AppColors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Por seguridad, sólo puedes retirar a una cuenta a tu nombre.',
          style: AppText.body(11, color: AppColors.grayLight),
        ),
      ],
    );
  }
}
