import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../navigation.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = false});

  final bool forced;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
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
      await context.read<AuthService>().changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (!mounted) return;
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();

      showAppSnack('Contraseña actualizada.');
      if (!widget.forced && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tu contraseña'),
          automaticallyImplyLeading: !widget.forced,
          actions: [
            if (widget.forced)
              TextButton(
                onPressed: _busy ? null : () => context.read<AuthService>().logout(),
                child: const Text('Salir'),
              ),
          ],
        ),
        body: ReadableSafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.forced) ...[
                    Text('Hola${auth.name != null ? ', ${auth.name!.split(' ').first}' : ''}',
                        style: AppText.display(24)),
                    const SizedBox(height: 8),
                    Text(
                      'Cambia la contraseña temporal por una tuya para empezar a pedir.',
                      style: AppText.body(14, color: AppColors.grayLight),
                    ),
                    const SizedBox(height: 28),
                  ],
                  TextFormField(
                    controller: _currentController,
                    enabled: !_busy,
                    obscureText: false,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [LengthLimitingTextInputFormatter(128)],
                    decoration: InputDecoration(
                      labelText: widget.forced ? 'Contraseña temporal' : 'Contraseña actual',
                      prefixIcon: const Icon(Icons.lock_clock),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Escribe tu contraseña actual' : null,
                    onFieldSubmitted: (_) => _newFocus.requestFocus(),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _newController,
                    focusNode: _newFocus,
                    enabled: !_busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    inputFormatters: [LengthLimitingTextInputFormatter(128)],
                    decoration: const InputDecoration(
                      labelText: 'Nueva contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                      helperText: 'Mínimo 8 caracteres',
                    ),
                    validator: (v) {
                      final s = v ?? '';
                      if (s.length < 8) return 'Debe tener al menos 8 caracteres';
                      if (s.trim() != s) return 'No puede empezar ni terminar con espacios';
                      if (s.trim() == _currentController.text.trim()) {
                        return 'Debe ser distinta de la actual';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmController,
                    focusNode: _confirmFocus,
                    enabled: !_busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [LengthLimitingTextInputFormatter(128)],
                    decoration: const InputDecoration(
                      labelText: 'Repite la nueva contraseña',
                      prefixIcon: Icon(Icons.lock_reset),
                    ),
                    validator: (v) =>
                        v != _newController.text ? 'Las contraseñas no coinciden' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: AppText.body(13, color: AppColors.danger)),
                  ],
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.midnight),
                          )
                        : const Text('Guardar contraseña'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
