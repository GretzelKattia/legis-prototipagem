import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../state/user_controller.dart';
import '../../state/favorites_controller.dart';
import '../../services/legis_api.dart';
import '../legal/terms_policies_screen.dart';
import '../onboarding/tutorial_screen.dart';
import 'login_screen.dart';

/// INTEGRAÇÃO BACK-END: POST /auth/register deve receber nome, e-mail e senha; validar
/// duplicidade de e-mail e política de senha no servidor, retornar perfil/token e exigir
/// confirmação de e-mail quando aplicável. Nunca armazenar senha em texto puro no app.


class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _accepted = false;
  bool _showTermsError = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _showTermsError = !_accepted);
    if (!valid || !_accepted) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final response = await context.read<LegisApi>().register(
        name: _name.text, email: _email.text, password: _password.text,
      );
      final user = Map<String, dynamic>.from(response['usuario'] as Map);
      final token = response['access_token']?.toString() ?? '';
      if (token.isEmpty) throw Exception('O servidor não retornou uma sessão válida.');
      await context.read<UserController>().saveSession(
        email: user['email']?.toString() ?? _email.text,
        name: user['nome']?.toString() ?? _name.text,
        token: token,
      );
      await context.read<FavoritesController>().load();
      if (!mounted) return;
      final navigator = Navigator.of(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conta criada com sucesso. Bem-vindo(a) ao LEGIS!')));
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => TutorialScreen(
          onFinished: () => navigator.pushNamedAndRemoveUntil('/home', (route) => false),
        )),
        (route) => route.isFirst,
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => route.isFirst,
    );
  }

  void _openTerms(int tab) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TermsPoliciesScreen(initialTab: tab)),
      );

  Widget _visibilityToggle(bool hidden, VoidCallback onTap) => IconButton(
        onPressed: onTap,
        tooltip: hidden ? 'Mostrar senha' : 'Ocultar senha',
        icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Crie sua conta', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text('Salve favoritos e acompanhe as atualizações das proposições que importam para você.', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(labelText: 'Nome completo', prefixIcon: Icon(Icons.person_outline_rounded)),
                      validator: (v) => (v ?? '').trim().length < 3 ? 'Informe seu nome completo.' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline_rounded)),
                      validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Informe um e-mail válido.',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: _visibilityToggle(_hidePassword, () => setState(() => _hidePassword = !_hidePassword)),
                      ),
                      validator: (v) => (v ?? '').length < 6 ? 'A senha deve ter pelo menos 10 caracteres.' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _hideConfirm,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _register(),
                      decoration: InputDecoration(
                        labelText: 'Confirmar senha',
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        suffixIcon: _visibilityToggle(_hideConfirm, () => setState(() => _hideConfirm = !_hideConfirm)),
                      ),
                      validator: (v) => v != _password.text ? 'As senhas não conferem.' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _accepted,
                          onChanged: (value) => setState(() {
                            _accepted = value ?? false;
                            if (_accepted) _showTermsError = false;
                          }),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 11),
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.45),
                                children: [
                                  const TextSpan(text: 'Li e aceito os '),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.baseline,
                                    baseline: TextBaseline.alphabetic,
                                    child: GestureDetector(
                                      onTap: () => _openTerms(0),
                                      child: Text('Termos de Uso', style: TextStyle(color: c.accentText, fontSize: 12.5, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: c.accentText)),
                                    ),
                                  ),
                                  const TextSpan(text: ' e a '),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.baseline,
                                    baseline: TextBaseline.alphabetic,
                                    child: GestureDetector(
                                      onTap: () => _openTerms(1),
                                      child: Text('Política de Privacidade', style: TextStyle(color: c.accentText, fontSize: 12.5, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: c.accentText)),
                                    ),
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_showTermsError)
                      Padding(
                        padding: const EdgeInsets.only(left: 14, top: 2),
                        child: Text('Aceite os termos para criar sua conta.', style: TextStyle(color: c.danger, fontSize: 11.5)),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 49,
                      child: FilledButton(
                        onPressed: _busy ? null : _register,
                        child: _busy
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.onAction))
                            : const Text('Criar conta'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Já tem uma conta?', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                        TextButton(onPressed: _goToLogin, child: const Text('Entrar')),
                      ],
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
