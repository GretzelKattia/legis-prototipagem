import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_state_views.dart';
import '../../core/widgets/legis_header.dart';
import '../../core/widgets/proposition_card.dart';
import '../../models/proposition.dart';
import '../../services/legis_api.dart';
import '../../state/favorites_controller.dart';
import '../preferences/preferences_screen.dart';

/// INTEGRAÇÃO BACK-END: alimentar a lista com GET /proposicoes, incluindo paginação,
/// busca e filtros por tipo, ano, situação e normas aprovadas. Usar parâmetros definidos
/// no contrato do backend; distinguir carregamento, lista vazia, erro e atualização.


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<String> _filters = const ['Todos', 'Favoritos', 'Em tramitação', 'Normas'];
  List<Proposition> _items = [];
  String _filter = 'Todos';
  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 180) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && !_hasMore)) return;
    if (reset) {
      _page = 0;
      _hasMore = true;
      _items = [];
      _error = null;
    }
    setState(() => _loading = true);
    try {
      final next = _page + 1;
      String? status;
      if (_filter == 'Em tramitação') status = 'EM_TRAMITACAO';
      if (_filter == 'Normas') status = 'TRANSFORMADA_EM_NORMA';
      if (_filter == 'Favoritos') {
        final favorites = await context.read<LegisApi>().getFavorites();
        if (!mounted) return;
        setState(() {
          _items = favorites;
          _page = 1;
          _hasMore = false;
          _error = null;
        });
      } else {
        final page = await context.read<LegisApi>().getPropositions(
              page: next,
              perPage: 20,
              status: status,
            );
        if (!mounted) return;
        setState(() {
          _page = page.page;
          _items.addAll(page.items);
          _hasMore = page.hasMore && page.items.isNotEmpty;
          _error = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPreferences() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PreferencesScreen()));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final favoriteIds = context.watch<FavoritesController>().items.map((e) => e.id).toSet();
    final visible = _filter == 'Favoritos'
        ? _items.where((item) => favoriteIds.contains(item.id)).toList()
        : _items;
    final useDesktopGrid = MediaQuery.sizeOf(context).width >= 1400;

    return Scaffold(
      appBar: LegisHeader(onPreferences: _openPreferences),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 7, 18, 15),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Proposições legislativas', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text('Acompanhe temas e atualizações do Legislativo.', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 37,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final label = _filters[index];
                          final selected = _filter == label;
                          return ChoiceChip(
                            label: Text(label),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _filter = label);
                              _load(reset: true);
                            },
                            backgroundColor: c.surface,
                            selectedColor: c.action,
                            side: BorderSide(color: selected ? c.action : c.border),
                            labelStyle: TextStyle(
                              color: selected ? c.onAction : c.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            showCheckmark: false,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading && _items.isEmpty)
              const SliverFillRemaining(hasScrollBody: false, child: LoadingView(label: 'Carregando proposições...'))
            else if (_error != null && _items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyView(
                  icon: Icons.cloud_off_outlined,
                  title: 'Não foi possível carregar as proposições',
                  description: _error,
                  actionLabel: 'Tentar novamente',
                  onAction: () => _load(reset: true),
                ),
              )
            else if (visible.isEmpty && !_loading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyView(
                  icon: _filter == 'Favoritos' ? Icons.bookmark_border : Icons.search_off_rounded,
                  title: _filter == 'Favoritos' ? 'Você ainda não favoritou nenhuma proposição.' : 'Nenhuma proposição encontrada.',
                  description: _filter == 'Favoritos' ? 'Toque no marcador de um card para salvar uma proposição.' : null,
                ),
              )
            else if (useDesktopGrid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 285,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => PropositionCard(proposition: visible[index]),
                    childCount: visible.length,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= visible.length) {
                        return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 11),
                        child: PropositionCard(proposition: visible[index]),
                      );
                    },
                    childCount: visible.length + (_loading ? 1 : 0),
                  ),
                ),
              ),
            if (_error != null && _items.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Não foi possível carregar mais itens. ${_error!}', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
