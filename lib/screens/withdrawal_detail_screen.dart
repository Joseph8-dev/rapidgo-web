import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/withdrawal_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/responsive.dart';

class WithdrawalDetailScreen extends StatefulWidget {
  const WithdrawalDetailScreen({super.key, required this.withdrawalId});

  final int withdrawalId;

  @override
  State<WithdrawalDetailScreen> createState() => _WithdrawalDetailScreenState();
}

class _WithdrawalDetailScreenState extends State<WithdrawalDetailScreen>
    with WidgetsBindingObserver {
  static const Duration _interval = Duration(seconds: 10);
  static const Duration _ceiling = Duration(minutes: 20);

  Timer? _timer;
  DateTime? _startedAt;
  Withdrawal? _withdrawal;
  bool _loading = true;
  bool _inFlight = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startedAt = DateTime.now();
    unawaited(_refresh().then((_) => _schedule()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh().then((_) => _schedule()));
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (!mounted) return;
    final status = _withdrawal?.status;
    if (status != null && !status.isOpen) return;
    if (_startedAt != null && DateTime.now().difference(_startedAt!) > _ceiling) return;
    _timer = Timer(_interval, () async {
      await _refresh();
      _schedule();
    });
  }

  Future<void> _refresh() async {
    if (_inFlight || !mounted) return;
    _inFlight = true;
    try {
      final fresh = await context.read<WithdrawalService>().byId(widget.withdrawalId);
      if (!mounted) return;
      final changed = _withdrawal?.status != fresh.status;
      setState(() {
        _withdrawal = fresh;
        _loading = false;
        _error = null;
      });
      if (changed) {
        HapticFeedback.mediumImpact();
        if (fresh.status.isRefunded) {
          unawaited(context.read<AuthService>().refreshBalance());
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_withdrawal == null) _error = e.message;
      });
    } finally {
      _inFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _withdrawal;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu retiro'),
        actions: [
          IconButton(
            onPressed: () => unawaited(_refresh()),
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: ReadableSafeArea(
        child: w == null
            ? _loading
                ? const Center(child: CircularProgressIndicator())
                : EmptyState(
                    icon: Icons.error_outline,
                    title: 'No pudimos cargar el retiro',
                    message: _error ?? '',
                    action: ElevatedButton(
                      onPressed: () => unawaited(_refresh()),
                      child: const Text('Reintentar'),
                    ),
                  )
            : RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.skyLight,
                backgroundColor: AppColors.surface,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _StatusCard(withdrawal: w),
                    const SizedBox(height: 20),
                    _DetailRow(label: 'Monto', value: w.amount.bs(), emphasise: true),
                    if (w.fee.isPositive) _DetailRow(label: 'Comisión', value: w.fee.bs()),
                    _DetailRow(label: 'Descontado', value: w.total.bs()),
                    const Divider(height: 28),
                    _DetailRow(label: 'Titular', value: w.benefNames),
                    _DetailRow(label: 'Banco', value: w.bankName),
                    _DetailRow(
                      label: w.payType == 'PMV' ? 'Pago Móvil' : 'Cuenta',
                      value: w.destinationMasked,
                    ),
                    if (w.bankReference != null) ...[
                      const Divider(height: 28),
                      _DetailRow(
                        label: 'Referencia bancaria',
                        value: w.bankReference!,
                        emphasise: true,
                        copyable: true,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Guarda esta referencia. Es el número con el que tu banco '
                        'puede rastrear la transferencia.',
                        style: AppText.body(11, color: AppColors.grayLight),
                      ),
                    ],
                    if (w.note != null && w.note!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(w.note!, style: AppText.body(12, color: AppColors.grayLight)),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.withdrawal});

  final Withdrawal withdrawal;

  Color get _color {
    switch (withdrawal.status) {
      case WithdrawalStatus.paid:
        return AppColors.success;
      case WithdrawalStatus.cancelled:
      case WithdrawalStatus.failedValidation:
        return AppColors.warning;
      case WithdrawalStatus.unknown:
      case WithdrawalStatus.needsReview:
        return AppColors.danger;
      default:
        return AppColors.skyLight;
    }
  }

  IconData get _icon {
    switch (withdrawal.status) {
      case WithdrawalStatus.paid:
        return Icons.check_circle;
      case WithdrawalStatus.cancelled:
      case WithdrawalStatus.failedValidation:
        return Icons.undo;
      case WithdrawalStatus.unknown:
      case WithdrawalStatus.needsReview:
        return Icons.help_outline;
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: _color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(_icon, color: _color, size: 40),
          const SizedBox(height: 12),
          Text(withdrawal.status.label,
              style: AppText.display(20, color: _color), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            withdrawal.status.detail,
            style: AppText.body(13, color: AppColors.grayLight),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasise = false,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool emphasise;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: AppText.body(12, color: AppColors.grayLight)),
          ),
          Expanded(
            child: Text(
              value,
              style: emphasise ? AppText.figure(15) : AppText.body(14),
              textAlign: TextAlign.right,
            ),
          ),
          if (copyable)
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'Copiar',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Referencia copiada')),
                );
              },
            ),
        ],
      ),
    );
  }
}
