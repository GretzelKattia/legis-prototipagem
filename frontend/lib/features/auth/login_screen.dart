import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../state/user_controller.dart';
import '../../state/favorites_controller.dart';
import '../../services/legis_api.dart';
import '../onboarding/tutorial_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

/// INTEGRAÇÃO BACK-END: enviar e-mail e senha por HTTPS a POST /auth/login. Tratar
/// token de acesso/refresh, expiração, erros 401/429 e perfil retornado. Guardar tokens
/// em armazenamento seguro (não SharedPreferences) e remover credenciais de demonstração.


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final response = await context.read<LegisApi>().login(email: _email.text, password: _password.text);
      final user = Map<String, dynamic>.from(response['usuario'] as Map);
      final token = response['access_token']?.toString() ?? '';
      if (token.isEmpty) throw Exception('O servidor não retornou uma sessão válida.');
      await context.read<UserController>().saveSession(
        email: user['email']?.toString() ?? _email.text,
        name: user['nome']?.toString() ?? '',
        token: token,
      );
      await context.read<FavoritesController>().load();
      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pushReplacement(MaterialPageRoute(
        builder: (_) => TutorialScreen(
          onFinished: () => navigator.pushNamedAndRemoveUntil('/home', (route) => false),
        ),
      ));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Image.asset('assets/images/legis_logo.png', fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('LEGIS', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Georgia', fontSize: 25, fontWeight: FontWeight.bold, color: c.text)),
                    const SizedBox(height: 7),
                    Text('Acesse sua conta para continuar', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 13)),
                    const SizedBox(height: 30),
                    Text('E-MAIL', style: TextStyle(color: c.text, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .3)),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: 'seu@email.com.br'),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty || !value.contains('@') || !value.contains('.')) return 'Informe um e-mail válido.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('SENHA', style: TextStyle(color: c.text, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .3)),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        hintText: 'Digite sua senha',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          tooltip: _hidePassword ? 'Mostrar senha' : 'Ocultar senha',
                          icon: Icon(_hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        ),
                      ),
                      validator: (v) => (v ?? '').length < 10 ? 'A senha deve ter pelo menos 10 caracteres.' : null,
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                        child: const Text('Esqueceu sua senha?'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 49,
                      child: FilledButton(
                        onPressed: _busy ? null : _login,
                        child: _busy
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.onAction))
                            : const Text('Entrar'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Ainda não tem conta?', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                          child: const Text('Criar conta'),
                        ),
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
