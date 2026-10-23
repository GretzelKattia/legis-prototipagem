import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../services/legis_api.dart';
import '../../core/theme/app_theme.dart';

/// INTEGRAÇÃO BACK-END: enviar senha atual e nova senha por HTTPS a POST /auth/change-password.
/// Exigir sessão válida, validar a senha no servidor, invalidar sessões conforme política
/// e nunca registrar a senha em logs ou persistir seu valor no dispositivo.


class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await context.read<LegisApi>().changePassword(currentPassword: _current.text, newPassword: _new.text);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Senha alterada com sucesso.')));
      navigator.pop();
    } catch (error) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Não foi possível alterar a senha: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _toggle(bool hidden, VoidCallback onTap) => IconButton(
        onPressed: onTap,
        tooltip: hidden ? 'Mostrar senha' : 'Ocultar senha',
        icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Alterar senha')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Crie uma senha forte, com pelo menos 10 caracteres, misturando letras e números.', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _current,
                      obscureText: _hideCurrent,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Senha atual',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: _toggle(_hideCurrent, () => setState(() => _hideCurrent = !_hideCurrent)),
                      ),
                      validator: (v) => (v ?? '').isEmpty ? 'Informe sua senha atual.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _new,
                      obscureText: _hideNew,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Nova senha',
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        suffixIcon: _toggle(_hideNew, () => setState(() => _hideNew = !_hideNew)),
                      ),
                      validator: (v) {
                        final value = v ?? '';
                        if (value.length < 10) return 'A nova senha deve ter pelo menos 10 caracteres.';
                        if (!RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) {
                          return 'Use letras e números.';
                        }
                        if (value == _current.text) return 'A nova senha deve ser diferente da atual.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _hideConfirm,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Confirmar nova senha',
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        suffixIcon: _toggle(_hideConfirm, () => setState(() => _hideConfirm = !_hideConfirm)),
                      ),
                      validator: (v) => v != _new.text ? 'As senhas não conferem.' : null,
                    ),
                    const SizedBox(height: 26),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.onAction))
                          : const Text('Alterar senha'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
