import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/cedula_formatter.dart';
import '../widgets/go_logo.dart';
import '../widgets/responsive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _obscure = false;
  bool _busy = false;
  String? _error;
  bool _biometricOffered = false;

  @override
  void initState() {
    super.initState();
    unawaited(_prefill());
  }

  Future<void> _prefill() async {
    final auth = context.read<AuthService>();

    final saved = auth.username;
    if (saved != null && mounted) {
      _userController.text = CedulaInputFormatter.normalize(saved);
    }

    final canBio = await auth.biometricAvailable && await auth.biometricEnabled;
    if (!mounted) return;
    setState(() => _biometricOffered = canBio);
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await context.read<AuthService>().login(
            username: _userController.text,
            password: _passController.text,
          );
      if (mounted) _passController.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFor(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No pudimos iniciar sesión. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(ApiException e) {
    switch (e.code) {
      case 'temp_password_expired':
        return 'Tu contraseña temporal venció. Pide a un operador en taquilla que la restablezca.';
      case 'account_locked':
        return e.message;
      case 'account_disabled':
        return 'Tu cuenta está inhabilitada. Acude a taquilla.';
      case 'rate_limited':
        return 'Demasiados intentos. Espera un momento antes de reintentar.';
      default:
        return e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final split = MediaQuery.sizeOf(context).width >= Breakpoints.split;
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: _LoginLayout(
        split: split,
        form: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!split) ...[
                      const Center(child: GoLogo(height: 110)),
                      const SizedBox(height: 36),
                    ],
                    Text('Entra con tu cédula', style: AppText.display(24)),
                    const SizedBox(height: 8),
                    Text(
                      'Usa la contraseña que te dieron al registrar tu tarjeta.',
                      style: AppText.body(14, color: AppColors.grayLight),
                    ),
                    const SizedBox(height: 28),

                    TextFormField(
                      controller: _userController,
                      focusNode: _userFocus,
                      enabled: !_busy,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.characters,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      inputFormatters: const [CedulaInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Cédula',
                        hintText: 'V-12345678',
                        prefixIcon: Icon(Icons.badge_outlined),
                        helperText: 'Escribe solo los números. Para E, J, P o G, empieza con esa letra.',
                        helperMaxLines: 2,
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'Escribe tu cédula';
                        if (!CedulaInputFormatter.isComplete(s)) {
                          return 'Formato: V-12345678';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _passFocus.requestFocus(),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _passController,
                      focusNode: _passFocus,
                      enabled: !_busy,
                      obscureText: _obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      inputFormatters: [LengthLimitingTextInputFormatter(128)],
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                        ),
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Escribe tu contraseña' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: _error!),
                    ],

                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.midnight),
                            )
                          : const Text('Entrar'),
                    ),

                    if (_biometricOffered) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _biometricLogin,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Entrar con huella'),
                      ),
                    ],

                    const SizedBox(height: 28),
                    Text(
                      '¿No tienes cuenta? Se crea en taquilla al registrar tu tarjeta GoEvent.',
                      textAlign: TextAlign.center,
                      style: AppText.body(12, color: AppColors.grayLight),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _biometricLogin() async {
    final auth = context.read<AuthService>();
    final ok = await auth.authenticateBiometric();
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = 'No pudimos verificar tu huella.');
      return;
    }
    setState(() => _busy = true);
    try {
      await auth.restore();
      if (mounted && !auth.isAuthenticated) {
        setState(() => _error = 'Tu sesión expiró. Escribe tu contraseña.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppText.body(13))),
        ],
      ),
    );
  }
}

class _LoginLayout extends StatelessWidget {
  const _LoginLayout({required this.split, required this.form});

  final bool split;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    if (!split) return form;
    return Row(
      children: [
        const Expanded(flex: 6, child: _BrandPanel()),
        Expanded(
          flex: 5,
          child: ColoredBox(color: AppColors.midnightDeep, child: form),
        ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceAlt, AppColors.midnight, AppColors.midnightDeep],
        ),
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GoLogo(height: 170),
              const SizedBox(height: 40),
              Text('Tu comida, en tu asiento.', style: AppText.display(40)),
              const SizedBox(height: 16),
              Text(
                'Pide a los negocios del Estadio Monumental sin perderte el juego. '
                'Pagas con tu tarjeta GoEvent cuando te lo entregan.',
                style: AppText.body(16, color: AppColors.grayLight, height: 1.6),
              ),
              const SizedBox(height: 36),
              const _Feature(icon: Icons.storefront, text: 'Todos los negocios del estadio en un solo lugar'),
              const SizedBox(height: 14),
              const _Feature(icon: Icons.event_seat, text: 'Entrega directa en tu asiento'),
              const SizedBox(height: 14),
              const _Feature(icon: Icons.verified_user_outlined, text: 'Se cobra solo cuando confirmas que lo recibiste'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.skyDeep.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.skyDeep.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, size: 20, color: AppColors.skyLight),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: AppText.body(14))),
      ],
    );
  }
}
