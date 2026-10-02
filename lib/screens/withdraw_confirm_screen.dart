import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/withdrawal_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive.dart';
import '../utils/money.dart';
import 'withdrawal_detail_screen.dart';

class WithdrawConfirmScreen extends StatefulWidget {
  const WithdrawConfirmScreen({
    super.key,
    required this.amount,
    required this.config,
    this.savedAccount,
    this.payType,
    this.bankCode,
    this.benefNames,
    this.phoneNumber,
    this.accountNumber,
  });

  final Money amount;
  final WithdrawalConfig config;
  final SavedAccount? savedAccount;
  final String? payType;
  final String? bankCode;
  final String? benefNames;
  final String? phoneNumber;
  final String? accountNumber;

  @override
  State<WithdrawConfirmScreen> createState() => _WithdrawConfirmScreenState();
}

class _WithdrawConfirmScreenState extends State<WithdrawConfirmScreen> {
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  late final String _idempotencyKey = WithdrawalService.newIdempotencyKey();

  bool _saveAccount = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _isSaved => widget.savedAccount != null;

  String get _bankName {
    if (_isSaved) return widget.savedAccount!.bankName;
    for (final b in widget.config.banks) {
      if (b.code == widget.bankCode) return b.name;
    }
    return widget.bankCode ?? '';
  }

  String get _payType => _isSaved ? widget.savedAccount!.payType : (widget.payType ?? 'PMV');

  String get _destination {
    if (_isSaved) return widget.savedAccount!.destinationMasked;
    if (_payType == 'PMV') {
      final p = widget.phoneNumber ?? '';
      return p.length == 11 ? '${p.substring(0, 4)}-${p.substring(4, 7)}-${p.substring(7)}' : p;
    }
    final a = widget.accountNumber ?? '';
    return a.length == 20
        ? '${a.substring(0, 4)} ${a.substring(4, 8)} ${a.substring(8, 12)} ${a.substring(12, 16)} ${a.substring(16)}'
        : a;
  }

  String get _holder =>
      _isSaved ? widget.savedAccount!.benefNames : (widget.benefNames ?? '');

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();

    if (_passwordController.text.trim().isEmpty) {
      setState(() => _error = 'Escribe tu contraseña para autorizar el retiro.');
      _passwordFocus.requestFocus();
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final service = context.read<WithdrawalService>();
    final auth = context.read<AuthService>();

    try {
      int? accountId = widget.savedAccount?.id;
      if (accountId == null && _saveAccount) {
        try {
          accountId = await service.addAccount(
            payType: _payType,
            bankCode: widget.bankCode!,
            benefNames: _holder,
            phoneNumber: _payType == 'PMV' ? widget.phoneNumber : null,
            accountNumber: _payType == 'TRF' ? widget.accountNumber : null,
          );
        } on ApiException {
          accountId = null;
        }
      }

      final withdrawal = await service.request(
        amount: widget.amount,
        password: _passwordController.text,
        idempotencyKey: _idempotencyKey,
        accountId: accountId,
        payType: accountId == null ? _payType : null,
        bankCode: accountId == null ? widget.bankCode : null,
        benefNames: accountId == null ? _holder : null,
        phoneNumber: accountId == null && _payType == 'PMV' ? widget.phoneNumber : null,
        accountNumber: accountId == null && _payType == 'TRF' ? widget.accountNumber : null,
      );

      _passwordController.clear();
      unawaited(auth.refreshBalance());

      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => WithdrawalDetailScreen(withdrawalId: withdrawal.id),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = _explain(e));
      if (e.code == 'invalid_credentials') {
        _passwordController.clear();
        _passwordFocus.requestFocus();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No pudimos procesar el retiro. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _explain(ApiException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return 'Contraseña incorrecta.';
      case 'password_required':
        return 'Confirma tu contraseña para autorizar el retiro.';
      case 'account_locked':
        return 'Cuenta bloqueada temporalmente por intentos fallidos. Intenta más tarde.';
      case 'withdrawal_in_flight':
        return 'Ya tienes un retiro en proceso. Espera a que termine.';
      case 'ident_mismatch':
        return 'El retiro sólo puede ir a una cuenta a tu nombre.';
      case 'withdrawals_unavailable':
        return 'Los retiros no están disponibles ahora. Intenta más tarde.';
      case 'bank_mismatch':
      case 'invalid_account':
      case 'invalid_phone':
      case 'invalid_name':
      case 'withdrawal_rejected':
      case 'daily_limit':
      case 'insufficient_funds':
        return e.message;
      default:
        return e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fee = widget.config.feeFor(widget.amount);
    final total = widget.config.totalFor(widget.amount);

    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Confirmar retiro'),
          automaticallyImplyLeading: !_submitting,
        ),
        body: ReadableSafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.midnight,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Text('Vas a recibir', style: AppText.body(12, color: AppColors.grayLight)),
                    const SizedBox(height: 4),
                    FittedBox(child: Text(widget.amount.bs(), style: AppText.figure(34))),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              _Review(label: 'Titular', value: _holder),
              _Review(
                label: 'Cédula',
                value: widget.config.benefIdentDisplay.isNotEmpty
                    ? widget.config.benefIdentDisplay
                    : widget.config.benefIdent,
              ),
              _Review(label: 'Banco', value: _bankName),
              _Review(
                label: _payType == 'PMV' ? 'Pago Móvil' : 'Cuenta',
                value: _destination,
                emphasise: true,
              ),
              if (fee.isPositive) _Review(label: 'Comisión', value: fee.bs()),
              _Review(label: 'Se descuenta de tu saldo', value: total.bs(), emphasise: true),

              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Revisa bien el número. Una vez enviado, el dinero no se puede '
                        'recuperar si la cuenta es incorrecta.',
                        style: AppText.body(13),
                      ),
                    ),
                  ],
                ),
              ),

              if (!_isSaved) ...[
                const SizedBox(height: 6),
                CheckboxListTile(
                  value: _saveAccount,
                  onChanged: _submitting ? null : (v) => setState(() => _saveAccount = v ?? false),
                  activeColor: AppColors.skyLight,
                  checkColor: AppColors.midnight,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text('Guardar esta cuenta para la próxima',
                      style: AppText.body(13)),
                ),
              ],

              const SizedBox(height: 12),
              Text('Autoriza con tu contraseña', style: AppText.display(15)),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                enabled: !_submitting,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                inputFormatters: [LengthLimitingTextInputFormatter(128)],
                decoration: const InputDecoration(
                  labelText: 'Tu contraseña',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                onSubmitted: (_) => unawaited(_submit()),
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

              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.midnight),
                      )
                    : Text('Retirar ${widget.amount.bs()}'),
              ),
              const SizedBox(height: 10),
              Text(
                'El banco suele acreditar entre 3 y 15 minutos.',
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

class _Review extends StatelessWidget {
  const _Review({required this.label, required this.value, this.emphasise = false});

  final String label;
  final String value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AppText.body(12, color: AppColors.grayLight)),
          ),
          Expanded(
            child: Text(
              value,
              style: emphasise
                  ? AppText.figure(15, color: AppColors.white)
                  : AppText.body(14),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
