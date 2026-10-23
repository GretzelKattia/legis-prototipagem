import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';

/// INTEGRAÇÃO BACK-END: conteúdo pode permanecer estático versionado no app ou vir de
/// endpoint público de conteúdo legal. Se houver aceite obrigatório, registrar versão,
/// data/hora e usuário no servidor, sem tratar a simples abertura como aceite.


/// Termos de Uso e Política de Privacidade em abas.
/// [initialTab]: 0 = Termos de Uso, 1 = Política de Privacidade.
class TermsPoliciesScreen extends StatelessWidget {
  const TermsPoliciesScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab.clamp(0, 1).toInt(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Termos e políticas'),
          bottom: const TabBar(
            labelColor: AppColors.offWhite,
            unselectedLabelColor: AppColors.slate,
            indicatorColor: AppColors.tealLight,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            tabs: [Tab(text: 'Termos de Uso'), Tab(text: 'Privacidade')],
          ),
        ),
        body: const TabBarView(
          children: [
            _LegalDocument(
              title: 'Termos de Uso',
              intro: 'Bem-vindo(a) ao LEGIS! Escrevemos este texto de forma simples, para você saber o que esperar do aplicativo e o que esperamos de você.',
              sections: _termsSections,
            ),
            _LegalDocument(
              title: 'Política de Privacidade',
              intro: 'Sua privacidade importa. Aqui explicamos, sem juridiquês, quais informações o LEGIS usa e como você pode controlá-las.',
              sections: _privacySections,
            ),
          ],
        ),
      ),
    );
  }
}

class _Section {
  const _Section(this.title, this.body);
  final String title;
  final String body;
}

const _termsSections = <_Section>[
  _Section('1. O que é o LEGIS',
      'O LEGIS é um aplicativo que organiza informações legislativas públicas para facilitar a consulta e o acompanhamento por qualquer cidadão. Ele não é um canal oficial do Governo, da Câmara dos Deputados ou do Senado Federal.'),
  _Section('2. Como você pode usar',
      'Você pode usar o LEGIS para pesquisar proposições, acompanhar tramitações, salvar favoritos e receber avisos. O uso é pessoal e de boa-fé. Pedimos apenas que você não tente atrapalhar o funcionamento do app, copiar o serviço em massa ou usá-lo para fins ilegais.'),
  _Section('3. Sua conta',
      'Para salvar favoritos e preferências, você pode criar uma conta com nome, e-mail e senha. Informe dados verdadeiros e mantenha sua senha em segurança. Se notar algo estranho na sua conta, fale com a gente.'),
  _Section('4. Sobre as informações exibidas',
      'Os dados vêm de fontes públicas e podem ter atraso ou diferenças em relação ao registro oficial. Por isso, o LEGIS tem caráter informativo: para qualquer uso formal, jurídico ou profissional, confirme sempre na fonte oficial. Quando a vigência de uma norma não foi conferida, avisamos na tela.'),
  _Section('5. Notificações',
      'Você escolhe quais avisos quer receber e pode mudar isso a qualquer momento em Preferências. Os avisos são um apoio e não substituem a consulta às fontes oficiais.'),
  _Section('6. Propriedade intelectual',
      'O nome, o logotipo (balança e martelo) e o visual do LEGIS pertencem ao projeto. As informações legislativas públicas continuam sendo públicas: nós apenas as organizamos de um jeito mais fácil de ler.'),
  _Section('7. Mudanças nestes termos',
      'O LEGIS vai evoluir e estes termos podem ser atualizados. Quando houver mudanças importantes, avisaremos dentro do aplicativo. Continuar usando o app depois do aviso significa que você concorda com a nova versão.'),
  _Section('8. Fale com a gente',
      'Dúvidas, sugestões ou reclamações? Escreva para ${AppConfig.supportEmail} ou use a tela Ajuda e suporte.'),
];

const _privacySections = <_Section>[
  _Section('1. Quais informações usamos',
      'Usamos o que você nos informa (nome e e-mail), suas proposições favoritas e suas preferências de notificação. Também podemos registrar informações técnicas básicas, como versão do app e tipo de aparelho, para corrigir erros.'),
  _Section('2. Para que usamos',
      'Para criar e manter sua conta, mostrar seus favoritos, enviar os avisos que você escolheu, melhorar o aplicativo e oferecer suporte. Não usamos seus dados para vender anúncios.'),
  _Section('3. Onde ficam seus dados',
      'Nesta fase do projeto, nome, e-mail, tema e preferências ficam salvos no próprio dispositivo. Senhas não são gravadas. Quando o LEGIS passar a usar um servidor, esta política será atualizada para explicar como os dados são armazenados.'),
  _Section('4. Compartilhamento',
      'Não vendemos suas informações. Elas só serão compartilhadas se for necessário para o funcionamento do serviço (por exemplo, envio de notificações), por obrigação legal ou com a sua autorização.'),
  _Section('5. Seus direitos',
      'Pela Lei Geral de Proteção de Dados (LGPD), você pode pedir acesso, correção ou exclusão dos seus dados, além de retirar o seu consentimento quando quiser. Você pode editar seu perfil direto no app e pedir a exclusão pelo suporte.'),
  _Section('6. Segurança',
      'Adotamos cuidados razoáveis para proteger suas informações. Mesmo assim, nenhum sistema é 100% seguro; use uma senha forte e não a compartilhe.'),
  _Section('7. Atualizações desta política',
      'Podemos atualizar esta política para refletir mudanças no aplicativo ou na lei. A data da última revisão aparece no topo desta página.'),
  _Section('8. Contato',
      'Para exercer seus direitos ou tirar dúvidas sobre privacidade, escreva para ${AppConfig.supportEmail}.'),
];

class _LegalDocument extends StatelessWidget {
  const _LegalDocument({required this.title, required this.intro, required this.sections});
  final String title;
  final String intro;
  final List<_Section> sections;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('Última atualização: 19 de outubro de 2026', style: TextStyle(color: c.accentText, fontSize: 11.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(intro, style: TextStyle(color: c.text, fontSize: 14, height: 1.55)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.warningSoft, borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 17, color: c.warning),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Texto-modelo do protótipo. Antes de publicar o aplicativo, revise este conteúdo com assessoria jurídica.',
                      style: TextStyle(color: c.warning, fontSize: 11.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (final section in sections)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(section.title, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(section.body, style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.55)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
