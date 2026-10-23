import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';

/// INTEGRAÇÃO BACK-END: tela pública sem chamada obrigatória. O botão de entrar deve
/// seguir para autenticação real; após login válido, carregar perfil e encaminhar ao tutorial
/// apenas quando necessário, sem liberar telas protegidas antes de validar a sessão.


class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactHeight = constraints.maxHeight < 650;
            final content = Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 20, 26, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: compactHeight ? 2 : 14),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 330,
                          maxHeight: compactHeight ? 285 : 355,
                        ),
                        child: Image.asset(
                          'assets/images/legis_logo.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          semanticLabel: 'Logomarca LEGIS com balança da justiça e martelo',
                        ),
                      ),
                      SizedBox(height: compactHeight ? 4 : 12),
                      const Text(
                        'Informação legislativa de forma\nsimples e acessível.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.offWhite, fontSize: 16, height: 1.55, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(height: compactHeight ? 18 : 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.offWhite,
                            foregroundColor: AppColors.navy,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [Text('Começar'), SizedBox(width: 8), Icon(Icons.arrow_forward_rounded, size: 19)],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.offWhite,
                            side: const BorderSide(color: AppColors.tealLight, width: 1.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                          child: const Text('Criar conta'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Dados oficiais tratados da Câmara dos Deputados',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.slate, fontSize: 11.5, height: 1.4),
                      ),
                      SizedBox(height: compactHeight ? 0 : 8),
                    ],
                  ),
                ),
              ),
            );
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }
}
