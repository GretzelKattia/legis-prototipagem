import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_state_views.dart';
import '../../core/widgets/legis_header.dart';
import '../../core/widgets/proposition_card.dart';
import '../../models/proposition.dart';
import '../../services/legis_api.dart';
import '../preferences/preferences_screen.dart';

/// INTEGRAÇÃO BACK-END: usar endpoint de pesquisa de proposições com termo, tipo, ano,
/// situação e paginação. Aplicar debounce no campo de busca, cancelar/ignorar respostas
/// antigas e exibir erros, ausência de resultados e filtros ativos.


class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  List<Proposition> _items = [];
  bool _loading = false;
  String? _error;
  String? _tipo;
  String? _ano;
  String? _status;
  bool _hasSearched = false;
  int _requestId = 0;
  int _page = 0;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients && _scrollController.position.extentAfter < 360) {
      _search(nextPage: true);
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _requestId++;
      setState(() {
        _items = [];
        _hasSearched = false;
        _error = null;
        _loading = false;
      });
      if (_tipo != null || _ano != null || _status != null) {
        _debounce = Timer(const Duration(milliseconds: 250), () => _search());
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search());
  }

  Future<void> _search({bool nextPage = false}) async {
    if (_queryController.text.trim().isEmpty && _tipo == null && _ano == null && _status == null) return;
    if (nextPage && (_loading || _page >= _totalPages)) return;
    final requestId = nextPage ? _requestId : ++_requestId;
    final targetPage = nextPage ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _error = null;
      _hasSearched = true;
      if (!nextPage) { _items = []; _page = 0; _totalPages = 1; }
    });
    try {
      final result = await context.read<LegisApi>().getPropositions(
            query: _queryController.text,
            tipo: _tipo,
            ano: _ano,
            status: _status,
            page: targetPage,
            perPage: 20,
          );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        if (nextPage) { _items.addAll(result.items); } else { _items = result.items; }
        _page = result.page;
        _totalPages = result.totalPages;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _openFilters() async {
    String? tipo = _tipo;
    String? ano = _ano;
    String? status = _status;
    final yearController = TextEditingController(text: ano ?? '');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Text('Filtros de pesquisa', style: Theme.of(context).textTheme.headlineMedium), const Spacer(), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
              const SizedBox(height: 17),
              DropdownButtonFormField<String>(
                value: tipo,
                decoration: const InputDecoration(labelText: 'Tipo de proposição'),
                items: const [DropdownMenuItem(value: null, child: Text('Todos os tipos')), DropdownMenuItem(value: 'PL', child: Text('Projeto de Lei (PL)')), DropdownMenuItem(value: 'PEC', child: Text('Proposta de Emenda (PEC)')), DropdownMenuItem(value: 'PLP', child: Text('Projeto de Lei Complementar (PLP)')), DropdownMenuItem(value: 'MPV', child: Text('Medida Provisória (MPV)')), DropdownMenuItem(value: 'PDL', child: Text('Projeto de Decreto Legislativo (PDL)')), DropdownMenuItem(value: 'PRC', child: Text('Projeto de Resolução (PRC)'))],
                onChanged: (value) => setSheetState(() => tipo = value),
              ),
              const SizedBox(height: 12),
              TextField(controller: yearController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ano', hintText: 'Ex.: 2024')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Situação'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todas as situações')),
                  DropdownMenuItem(value: 'EM_TRAMITACAO', child: Text('Em tramitação')),
                  DropdownMenuItem(value: 'PRONTA_PARA_PAUTA', child: Text('Pronta para pauta')),
                  DropdownMenuItem(value: 'AGUARDANDO_SENADO', child: Text('Aguardando Senado')),
                  DropdownMenuItem(value: 'APROVADA', child: Text('Aprovada')),
                  DropdownMenuItem(value: 'TRANSFORMADA_EM_NORMA', child: Text('Transformada em norma')),
                  DropdownMenuItem(value: 'VIGENCIA_VERIFICADA', child: Text('Vigência verificada')),
                  DropdownMenuItem(value: 'ARQUIVADA', child: Text('Arquivada')),
                  DropdownMenuItem(value: 'REJEITADA', child: Text('Rejeitada')),
                  DropdownMenuItem(value: 'PREJUDICADA', child: Text('Prejudicada')),
                  DropdownMenuItem(value: 'DESCONHECIDA', child: Text('Situação não identificada')),
                ],
                onChanged: (value) => setSheetState(() => status = value),
              ),
              const SizedBox(height: 20),
              Row(children: [Expanded(child: OutlinedButton(onPressed: () { setState(() { _tipo = null; _ano = null; _status = null; }); Navigator.pop(context); if (_queryController.text.trim().isEmpty) { _requestId++; setState(() { _items = []; _error = null; _hasSearched = false; _loading = false; }); } else { _search(); } }, child: const Text('Limpar'))), const SizedBox(width: 12), Expanded(child: FilledButton(onPressed: () { setState(() { _tipo = tipo; _ano = yearController.text.trim().isEmpty ? null : yearController.text.trim(); _status = status; }); Navigator.pop(context); _search(); }, child: const Text('Aplicar filtros')))]),
            ],
          ),
        ),
      ),
    );
    yearController.dispose();
  }

  Future<void> _openPreferences() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PreferencesScreen()));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final activeStatus = _status;
    return Scaffold(
      appBar: LegisHeader(onPreferences: _openPreferences),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Explorar', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text('Pesquise por número, autor ou palavras da ementa.', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      onChanged: _onQueryChanged,
                      onSubmitted: (_) => _search(),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Pesquise projetos, autores, temas...',
                        prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary),
                        suffixIcon: _queryController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.close), onPressed: () { _queryController.clear(); _onQueryChanged(''); }) : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(color: c.action, borderRadius: BorderRadius.circular(13)),
                    child: IconButton(onPressed: _openFilters, icon: Icon(Icons.tune_rounded, color: c.onAction), tooltip: 'Filtros'),
                  ),
                ]),
                if (_tipo != null || _ano != null || activeStatus != null) ...[
                  const SizedBox(height: 9),
                  Wrap(spacing: 7, children: [
                    if (_tipo != null) _FilterPill(label: _tipo!),
                    if (_ano != null) _FilterPill(label: _ano!),
                    if (activeStatus != null) _FilterPill(label: activeStatus.replaceAll('_', ' ').toLowerCase()),
                  ]),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading && _items.isEmpty
                ? const LoadingView(label: 'Pesquisando proposições...')
                : _error != null && _items.isEmpty
                    ? EmptyView(icon: Icons.cloud_off_outlined, title: 'Não foi possível realizar a pesquisa', description: _error, actionLabel: 'Tentar novamente', onAction: () => _search())
                    : !_hasSearched
                        ? const EmptyView(icon: Icons.search_rounded, title: 'Digite um termo ou escolha filtros para começar.', description: 'Você pode refinar a busca com os filtros de tipo, ano e situação.')
                        : _items.isEmpty
                            ? const EmptyView(icon: Icons.search_off_rounded, title: 'Nenhuma proposição corresponde aos filtros informados.')
                            : RefreshIndicator(
                                onRefresh: () => _search(),
                                child: MediaQuery.sizeOf(context).width >= 1400
                                    ? GridView.builder(
                                        controller: _scrollController,
                                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 14,
                                          mainAxisSpacing: 12,
                                          mainAxisExtent: 285,
                                        ),
                                        itemCount: _items.length + (_loading || _error != null ? 1 : 0),
                                        itemBuilder: (context, index) => index >= _items.length
                                            ? (_loading ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())) : Padding(padding: const EdgeInsets.all(12), child: Text(_error ?? '')))
                                            : PropositionCard(proposition: _items[index]),
                                      )
                                    : ListView.separated(
                                        controller: _scrollController,
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                        itemCount: _items.length + (_loading || _error != null ? 1 : 0),
                                        separatorBuilder: (_, __) => const SizedBox(height: 11),
                                        itemBuilder: (context, index) => index >= _items.length
                                            ? (_loading ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())) : Padding(padding: const EdgeInsets.all(12), child: Text(_error ?? '')))
                                            : PropositionCard(proposition: _items[index]),
                                      ),
                              ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Chip(label: Text(label, style: TextStyle(fontSize: 10.5, color: c.onAccentSoft, fontWeight: FontWeight.w600)), visualDensity: VisualDensity.compact, backgroundColor: c.accentSoft, side: BorderSide.none);
  }
}
