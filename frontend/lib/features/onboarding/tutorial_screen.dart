import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';

/// INTEGRAÇÃO BACK-END: tutorial pode continuar local. Se o progresso precisar ser
/// sincronizado entre dispositivos, persistir conclusão na conta; não bloquear acesso
/// por falha de rede. Manter claro o fluxo após autenticação bem-sucedida.


class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  final _content = const [
    _TutorialPageData(
      icon: Icons.search_rounded,
      title: 'Encontre proposições',
      description: 'Pesquise por palavra-chave, tipo, ano ou tema de interesse.',
    ),
    _TutorialPageData(
      icon: Icons.timeline_rounded,
      title: 'Acompanhe as tramitações',
      description: 'Veja autores, situação atual e o histórico de tramitações.',
    ),
    _TutorialPageData(
      icon: Icons.bookmark_outline_rounded,
      title: 'Organize seus favoritos',
      description: 'Salve proposições para encontrá-las rapidamente e acompanhar suas atualizações.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_concluido', true);
    if (mounted) widget.onFinished();
  }

  void _next() {
    if (_page == _content.length - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 240), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final lastPage = _page == _content.length - 1;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.text,
        leading: const SizedBox.shrink(),
        actions: [
          TextButton(onPressed: _finish, child: const Text('Pular')),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _content.length,
                    onPageChanged: (index) => setState(() => _page = index),
                    itemBuilder: (context, index) {
                      final item = _content[index];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(28, 24, 28, 15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(14)),
                              child: Icon(item.icon, color: AppColors.offWhite, size: 24),
                            ),
                            const SizedBox(height: 24),
                            Text(item.title, style: Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 12),
                            Text(item.description, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: c.textSecondary)),
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FeatureLine(text: 'Consulte proposições legislativas'),
                                  SizedBox(height: 10),
                                  _FeatureLine(text: 'Busque por autor e tema'),
                                  SizedBox(height: 10),
                                  _FeatureLine(text: 'Acompanhe favoritos e atualizações'),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Center(child: Text('${index + 1} de ${_content.length}', style: TextStyle(color: c.textSecondary, fontSize: 11))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _content.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: 5,
                            width: index == _page ? 23 : 7,
                            decoration: BoxDecoration(
                              color: index == _page ? c.accent : c.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _next,
                          child: Text(lastPage ? 'Começar a usar' : 'Próximo'),
                        ),
                      ),
                      const SizedBox(height: 7),
                      if (!lastPage)
                        TextButton(onPressed: _finish, child: Text('Pular', style: TextStyle(color: c.textSecondary))),
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

class _TutorialPageData {
  const _TutorialPageData({required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title;
  final String description;
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Row(
      children: [
        Icon(Icons.check_circle_outline, color: c.accent, size: 17),
        const SizedBox(width: 9),
        Expanded(child: Text(text, style: TextStyle(color: c.text, fontSize: 12.5))),
      ],
    );
  }
}
