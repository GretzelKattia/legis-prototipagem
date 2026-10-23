import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 42, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
                    child: Icon(Icons.lock_reset_rounded, color: c.accent, size: 33),
                  ),
                  const SizedBox(height: 20),
                  Text('Recuperação por e-mail indisponível', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  Text(
                    'O backend ainda não possui um serviço de envio de e-mail e de redefinição segura. Nenhuma mensagem será enviada. Você pode alterar a senha dentro da conta autenticada.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 49,
                    child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Voltar ao login')),
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
