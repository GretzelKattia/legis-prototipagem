import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_state_views.dart';
import '../../core/widgets/favorite_button.dart';
import '../../core/widgets/status_badge.dart';
import '../../models/author.dart';
import '../../models/proposition.dart';
import '../../models/tramitation.dart';
import '../../services/legis_api.dart';
import '../../state/favorites_controller.dart';

/// INTEGRAÇÃO BACK-END: carregar detalhes por GET /proposicoes/{id}, autores por
/// GET /proposicoes/{id}/autores e tramitações por GET /proposicoes/{id}/tramitacoes.
/// Mapear situação, vigência, datas e identificador oficial. Compartilhamento deve usar
/// URL pública/deep link estável. Favoritos devem sincronizar com API autenticada.


class PropositionDetailScreen extends StatefulWidget {
  const PropositionDetailScreen({super.key, required this.proposition});
  final Proposition proposition;

  @override
  State<PropositionDetailScreen> createState() => _PropositionDetailScreenState();
}

class _PropositionDetailScreenState extends State<PropositionDetailScreen> {
  late Future<Proposition> _detailFuture;
  late Future<List<Author>> _authorsFuture;
  late Future<List<Tramitation>> _tramitationFuture;

  /// Versão mais completa já carregada (usada ao favoritar).
  Proposition? _loaded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = context.read<LegisApi>();
    _detailFuture = api.getProposition(widget.proposition.id).then((item) {
      _loaded = item;
      return item;
    });
    _authorsFuture = api.getAuthors(widget.proposition.id);
    _tramitationFuture = api.getTramitations(widget.proposition.id);
  }

  Proposition get _current => _loaded ?? widget.proposition;

  String _propositionUrl(Proposition item) => 'https://www.camara.leg.br/proposicoesWeb/fichadetramitacao?idProposicao=${item.id}';

  Future<void> _shareProposition(Proposition item) async {
    final title = item.titulo.isNotEmpty ? item.titulo : _identify(item);
    final url = _propositionUrl(item);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copiado para a área de transferência!')));
    await Share.share('$title\n$url', subject: title);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final initial = widget.proposition;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back)),
        title: const Text('Detalhes da proposição'),
        actions: [
          // Favoritar na AppBar: reativo e sincronizado com o botão do rodapé.
          Builder(builder: (context) => FavoriteButton(proposition: _current, onDark: true, showConfirmation: true)),
          IconButton(
            onPressed: () => _shareProposition(_current),
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartilhar proposição',
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: _FavoriteFooter(proposition: () => _current),
      body: FutureBuilder<Proposition>(
        future: _detailFuture,
        builder: (context, snapshot) {
          final item = snapshot.data ?? initial;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingView(label: 'Carregando detalhes...'));
          }
          if (snapshot.hasError && snapshot.data == null) {
            return EmptyView(
              icon: Icons.cloud_off_outlined,
              title: 'Não foi possível carregar todos os detalhes',
              description: snapshot.error.toString(),
              actionLabel: 'Tentar novamente',
              onAction: () => setState(_load),
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: c.hero,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: c.border),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_identify(item), style: const TextStyle(color: AppColors.tealTint, fontSize: 11.5, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Text(item.titulo.isNotEmpty ? item.titulo : 'Informação não disponível', style: TextStyle(color: c.onHero, fontSize: 17, height: 1.4, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      StatusBadge(label: item.status.rotulo),
                      if (item.status.detalhe != null) ...[
                        const SizedBox(height: 8),
                        Text(item.status.detalhe!, style: TextStyle(color: c.onHeroMuted, fontSize: 12)),
                      ],
                      const SizedBox(height: 10),
                      Text('Atualizado em ${item.updatedLabel}', style: TextStyle(color: c.onHeroMuted, fontSize: 11)),
                      const SizedBox(height: 7),
                      Text(
                        '${item.status.vigenciaVerificada ? 'Vigência verificada' : 'Vigência não verificada'}${item.leiNumero != null ? ' • Norma relacionada: ${item.leiTipo ?? 'Lei'} nº ${item.leiNumero}' : ''}${item.leiDataPublicacao != null ? ' • Publicação: ${item.leiDataPublicacao}' : ''}',
                        style: TextStyle(color: c.onHeroMuted, fontSize: 11.5, height: 1.35),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 13),
                  _sectionCard(
                    context,
                    title: 'Dados da proposição',
                    child: Column(children: [
                      _InfoRow(label: 'Ementa', value: item.ementa ?? (item.titulo.isNotEmpty ? item.titulo : null)),
                      _InfoRow(label: 'Data de apresentação', value: item.presentationDateLabel),
                      _InfoRow(label: 'Tipo', value: item.tipo.isNotEmpty ? item.tipo : null),
                      _InfoRow(label: 'Número', value: item.numero.isNotEmpty ? item.numero : null),
                      _InfoRow(label: 'Ano', value: item.ano > 0 ? '${item.ano}' : null, last: true),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _sectionCard(
                    context,
                    title: 'Autores',
                    child: FutureBuilder<List<Author>>(
                      future: _authorsFuture,
                      builder: (context, authorsSnapshot) {
                        if (authorsSnapshot.connectionState == ConnectionState.waiting) return const LoadingView(label: 'Carregando autores...');
                        if (authorsSnapshot.hasError || authorsSnapshot.data == null || authorsSnapshot.data!.isEmpty) {
                          if (item.autorNome != null) return _AuthorTile(author: Author(nome: item.autorNome!));
                          return Text('Informação não disponível', style: TextStyle(color: c.textSecondary, fontSize: 12));
                        }
                        return Column(children: authorsSnapshot.data!.map((author) => _AuthorTile(author: author)).toList());
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionCard(
                    context,
                    title: 'Histórico de tramitação',
                    child: FutureBuilder<List<Tramitation>>(
                      future: _tramitationFuture,
                      builder: (context, tramSnapshot) {
                        if (tramSnapshot.connectionState == ConnectionState.waiting) return const LoadingView(label: 'Carregando tramitações...');
                        if (tramSnapshot.hasError || tramSnapshot.data == null || tramSnapshot.data!.isEmpty) {
                          return Text('Não há tramitações disponíveis para esta proposição.', style: TextStyle(color: c.textSecondary, fontSize: 12));
                        }
                        final events = [...tramSnapshot.data!]..sort((a, b) => a.sequencia.compareTo(b.sequencia));
                        return Column(children: List.generate(events.length, (index) => _TimelineTile(event: events[index], isLast: index == events.length - 1)));
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _identify(Proposition item) {
    if (item.tipo.isEmpty || item.numero.isEmpty) return 'Proposição ${item.id}';
    return '${item.tipo} ${item.numero}/${item.ano}';
  }

  Widget _sectionCard(BuildContext context, {required String title, required Widget child}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.palette.text)),
            const SizedBox(height: 13),
            child,
          ]),
        ),
      );
}

/// Botão do rodapé. Observa o FavoritesController e muda ícone, rótulo e cores
/// imediatamente após o toque.
class _FavoriteFooter extends StatelessWidget {
  const _FavoriteFooter({required this.proposition});
  final Proposition Function() proposition;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Consumer<FavoritesController>(
      builder: (context, favorites, _) {
        final item = proposition();
        final isFavorite = favorites.isFavorite(item.id);
        return Container(
          decoration: BoxDecoration(
            color: c.background,
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: SizedBox(
                    width: double.infinity,
                    height: 49,
                    child: FilledButton.icon(
                      onPressed: () => toggleFavoriteWithFeedback(context, item, showConfirmation: true),
                      icon: Icon(
                        isFavorite ? Icons.bookmark : Icons.bookmark_border,
                        color: isFavorite ? c.accent : c.onAction,
                      ),
                      label: Text(isFavorite ? 'Remover dos favoritos' : 'Adicionar aos favoritos'),
                      style: FilledButton.styleFrom(
                        backgroundColor: isFavorite ? c.surface : c.action,
                        foregroundColor: isFavorite ? c.text : c.onAction,
                        side: BorderSide(color: isFavorite ? c.accent : Colors.transparent, width: 1.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value, this.last = false});
  final String label;
  final String? value;
  final bool last;
  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.border))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 125, child: Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11.5))),
        Expanded(child: Text(value ?? 'Informação não disponível', style: TextStyle(color: c.text, fontSize: 12.5, height: 1.35))),
      ]),
    );
  }
}

class _AuthorTile extends StatelessWidget {
  const _AuthorTile({required this.author});
  final Author author;
  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(children: [
        CircleAvatar(radius: 17, backgroundColor: c.accentSoft, child: Icon(Icons.person_outline, size: 18, color: c.accent)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(author.nome, style: TextStyle(color: c.text, fontSize: 12.5, fontWeight: FontWeight.w600)),
            if (author.tipo != null) Text(author.tipo!, style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ]),
        ),
        if (author.proponente) Text('Proponente', style: TextStyle(color: c.accentText, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event, required this.isLast});
  final Tramitation event;
  final bool isLast;
  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 22,
          child: Column(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
            if (!isLast) Expanded(child: Container(width: 1.3, color: c.border)),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 17),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event.dataLabel, style: TextStyle(color: c.accentText, fontSize: 10.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              if (event.situacao != null) StatusBadge(label: _humanStatus(event.situacao!)),
              if (event.orgao != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text(event.orgao!, style: TextStyle(color: c.textSecondary, fontSize: 10.5))),
              if (event.descricao != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text(event.descricao!, style: TextStyle(color: c.text, fontSize: 12.5, height: 1.35))),
              if (event.despacho != null)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: ExpansionTile(
                    dense: true,
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 6),
                    title: Text('Ver despacho', style: TextStyle(fontSize: 11, color: c.accentText)),
                    children: [Align(alignment: Alignment.centerLeft, child: Text(event.despacho!, style: TextStyle(fontSize: 11.5, color: c.textSecondary)))],
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  String _humanStatus(String source) {
    final upper = source.toUpperCase();
    if (upper.contains('TRANSFORMADO EM NORMA') || upper.contains('TRANSFORMADA EM NORMA') || upper == '1140') return 'Transformada em Norma';
    if (upper == '924' || upper.contains('PRONTA PARA PAUTA')) return 'Pronta para pauta';
    if (upper == '926' || upper.contains('AGUARDANDO APRECIAÇÃO PELO SENADO')) return 'Aguardando Senado';
    return source;
  }
}
