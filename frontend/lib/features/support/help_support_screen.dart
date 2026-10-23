import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';

/// INTEGRAÇÃO BACK-END: se for criado canal de chamados, enviar assunto, descrição e
/// identificador da conta a POST /suporte/chamados; validar tamanho/limites, retornar protocolo
/// e evitar enviar tokens, senhas ou outros dados sensíveis no conteúdo do chamado.

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _faq = <(String, String)>[
    (
      'O que é o LEGIS?',
      'O LEGIS organiza informações legislativas públicas para você pesquisar proposições, acompanhar tramitações e salvar o que for do seu interesse.'
    ),
    (
      'De onde vêm as informações?',
      'De fontes públicas do Poder Legislativo, tratadas pelo nosso servidor. Pode haver atraso em relação ao registro oficial; para uso formal, confirme sempre na fonte oficial.'
    ),
    (
      'Como favorito uma proposição?',
      'Toque no ícone de marcador no card da proposição ou na tela de detalhes. O ícone preenche quando ela é salva; toque de novo para remover. Seus itens ficam na aba Favoritos.'
    ),
    (
      'Como recebo notificações?',
      'Em Preferências, escolha os tipos de aviso (novos projetos, atualizações, favoritos, votações). As notificações aparecem na aba Notificações; toque em uma para ver o conteúdo completo.'
    ),
    (
      'Como ativo o modo escuro?',
      'Abra Preferências e, em Aparência, escolha Modo claro, Modo escuro ou Seguir o sistema do celular.'
    ),
    (
      'Preciso ter uma conta?',
      'Para explorar o conteúdo, a conta é só o acesso ao app. Ela permite manter seu perfil, favoritos e preferências.'
    ),
    (
      'Esqueci minha senha. E agora?',
      'Na tela de login, toque em "Esqueceu sua senha?", informe o e-mail da conta e siga as instruções enviadas.'
    ),
    (
      'Como excluo meus dados?',
      'Você pode editar seu perfil a qualquer momento. Para excluir a conta e os dados, fale com o suporte pelo e-mail abaixo.'
    ),
  ];

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: AppConfig.supportEmail));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-mail de suporte copiado.')));
    }
  }

  void _openContactForm(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ContactSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajuda e suporte')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
            children: [
              Text('Como podemos ajudar?',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                  'Veja as respostas para as dúvidas mais comuns ou fale com a nossa equipe.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
              Text('PERGUNTAS FREQUENTES',
                  style: TextStyle(
                      color: c.accentText,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8)),
              const SizedBox(height: 10),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < _faq.length; i++) ...[
                      ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 2),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        expandedAlignment: Alignment.centerLeft,
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        title: Text(_faq[i].$1,
                            style: TextStyle(
                                color: c.text,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600)),
                        children: [
                          Text(_faq[i].$2,
                              style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 13,
                                  height: 1.55))
                        ],
                      ),
                      if (i != _faq.length - 1)
                        Divider(height: 1, color: c.border),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('FALE COM O SUPORTE',
                  style: TextStyle(
                      color: c.accentText,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8)),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: c.accentSoft,
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.support_agent_rounded,
                                color: c.accent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Não encontrou o que procurava?',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 3),
                                Text(
                                    'Nossa equipe responde assim que possível.',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openContactForm(context),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Enviar mensagem'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _copyEmail(context),
                          icon:
                              Icon(Icons.mail_outline_rounded, color: c.accent),
                          label: const Text(AppConfig.supportEmail),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactSheet extends StatefulWidget {
  const _ContactSheet();

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          'O envio de mensagens ainda não está configurado neste backend.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text('Enviar mensagem',
                          style: Theme.of(context).textTheme.headlineMedium)),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _subject,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Assunto'),
                validator: (v) =>
                    (v ?? '').trim().length < 3 ? 'Informe o assunto.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _message,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(
                    labelText: 'Mensagem', alignLabelWithHint: true),
                validator: (v) => (v ?? '').trim().length < 10
                    ? 'Descreva melhor o que você precisa.'
                    : null,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _send,
                child: _busy
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: context.palette.onAction))
                    : const Text('Enviar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
