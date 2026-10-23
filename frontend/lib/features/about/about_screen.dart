import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../legal/terms_policies_screen.dart';

/// INTEGRAÇÃO BACK-END: normalmente não precisa de endpoint. Se versão e links
/// legais forem administráveis, carregar versão/links de um endpoint público de
/// configuração; não colocar segredos nem dados pessoais nesta tela.


class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  void _openLegal(BuildContext context, int tab) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TermsPoliciesScreen(initialTab: tab)),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre o LEGIS')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
            children: [
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.teal, width: 1.6),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/images/legis_logo.png',
                      width: 168,
                      height: 168,
                      fit: BoxFit.cover,
                      semanticLabel: 'Logomarca LEGIS com balança da justiça e martelo',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('LEGIS', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Georgia', fontSize: 26, fontWeight: FontWeight.bold, color: c.text, letterSpacing: 2)),
              const SizedBox(height: 6),
              Text('Informação legislativa de forma simples e acessível.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(20)),
                  child: Text('Versão ${AppConfig.appVersion} (${AppConfig.appBuild})', style: TextStyle(color: c.onAccentSoft, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nossa proposta', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      Text(
                        'O LEGIS existe para aproximar o cidadão do processo legislativo. Reunimos proposições e leis em um só lugar, com linguagem clara, para que você possa entender o que está sendo discutido, acompanhar cada etapa da tramitação e ser avisado quando algo importante mudar.',
                        style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _Pillar(icon: Icons.search_rounded, title: 'Consulte', text: 'Pesquise proposições por tema, autor, tipo ou ano.'),
              const SizedBox(height: 9),
              const _Pillar(icon: Icons.timeline_rounded, title: 'Acompanhe', text: 'Veja autores, situação atual e o histórico de tramitação.'),
              const SizedBox(height: 9),
              const _Pillar(icon: Icons.notifications_active_outlined, title: 'Fique por dentro', text: 'Salve favoritos e receba avisos sobre novidades.'),
              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text('Termos de Uso', style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w600)),
                      trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                      onTap: () => _openLegal(context, 0),
                    ),
                    Divider(height: 1, color: c.border),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: Text('Política de Privacidade', style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w600)),
                      trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                      onTap: () => _openLegal(context, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'O LEGIS é uma iniciativa independente e não representa o Governo nem as Casas Legislativas. As informações têm caráter informativo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.5),
              ),
              const SizedBox(height: 10),
              Text('© 2026 LEGIS', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pillar extends StatelessWidget {
  const _Pillar({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: c.accent, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: c.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(text, style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
