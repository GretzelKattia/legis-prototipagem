import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../state/user_controller.dart';
import '../../services/legis_api.dart';

/// INTEGRAÇÃO BACK-END: buscar e atualizar perfil via GET/PATCH /usuarios/me. Validar
/// campos no servidor, atualizar o estado local após sucesso e apresentar conflitos/erros
/// de validação sem descartar silenciosamente as alterações do formulário.


class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserController>();
    _name = TextEditingController(text: user.name);
    _email = TextEditingController(text: user.email);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final saved = await context.read<LegisApi>().updateProfile(name: _name.text, email: _email.text);
      await context.read<UserController>().updateProfile(name: saved['nome']?.toString() ?? _name.text, email: saved['email']?.toString() ?? _email.text);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Perfil atualizado com sucesso.')));
      navigator.pop();
    } catch (error) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Não foi possível atualizar o perfil: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
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
                    Center(
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        child: Text(
                          _name.text.trim().isNotEmpty ? _name.text.trim()[0].toUpperCase() : user.initial,
                          style: const TextStyle(color: AppColors.offWhite, fontSize: 28, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Nome completo', prefixIcon: Icon(Icons.person_outline_rounded)),
                      validator: (v) => (v ?? '').trim().length < 3 ? 'Informe seu nome completo.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline_rounded)),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value) ? null : 'Informe um e-mail válido.';
                      },
                    ),
                    const SizedBox(height: 26),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.offWhite))
                          : const Text('Salvar alterações'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
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
