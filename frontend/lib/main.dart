import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Constantes
// const String _userId = 'admin123';
const String _userId = '1';
// const String _adminToken = 'supersecret_admin_token';
const String _adminToken = 'gere-um-token-local';
const String _baseUrl = 'http://localhost:8000';
const String _unavailable = 'Informação não disponível';
const String _errorTitle = 'Erro de Conexão';

// Utils
String formatDateTime(DateTime? dt) =>
    dt != null ? DateFormat('dd/MM/yyyy HH:mm').format(dt) : _unavailable;

String formatDate(DateTime? dt) =>
    dt != null ? DateFormat('dd/MM/yyyy').format(dt) : _unavailable;

String textOrUnavailable(String? text) =>
    (text != null && text.trim().isNotEmpty) ? text : _unavailable;

// Modelos Seguros e Mapeados Corretamente
class StatusInfo {
  final String label;
  final String rotulo;
  final String description;

  StatusInfo(this.label, this.rotulo, this.description);

  factory StatusInfo.fromJson(Map<String, dynamic> json) {
    final s = json['status'];

    // Função interna para embelezar o texto
    String beautify(String? text) {
      if (text == null || text.isEmpty || text == 'Situação não identificada') {
        return 'Fase Inicial'; // <-- AQUI ESTÁ O NOVO NOME
      }
      return text;
    }

    if (s is String) {
      return StatusInfo(s, beautify(s), _unavailable);
    } else if (s is Map) {
      return StatusInfo(
          s['ordem']?.toString() ?? 'Fase Inicial',
          beautify(s['rotulo']?.toString() ?? s['ordem']?.toString()),
          s['detalhe']?.toString() ?? _unavailable);
    }
    return StatusInfo('Fase Inicial', 'Fase Inicial', _unavailable);
  }
}

class Author {
  final String name;
  final String? type;
  final bool proponent;

  Author(this.name, this.type, this.proponent);

  factory Author.fromJson(Map<String, dynamic> json) => Author(
      json['nome'] ?? json['nome_autor'] ?? _unavailable,
      json['tipo'] ?? json['tipo_autor'],
      json['proponente'] == true || json['proponente'] == 1);
}

class Proceeding {
  final DateTime? date;
  final String? agency;
  final String? situation;
  final String? description;
  final String? dispatch;

  Proceeding(
      this.date, this.agency, this.situation, this.description, this.dispatch);

  factory Proceeding.fromJson(Map<String, dynamic> json) {
    // Se a situação vier nula, usamos um nome elegante
    String sit = json['situacao']?.toString() ??
        json['descricao_situacao']?.toString() ??
        'Movimentação Registrada'; // <-- NOVO NOME AQUI

    return Proceeding(
        json['data_hora'] != null ? DateTime.tryParse(json['data_hora']) : null,
        json['orgao']?.toString() ?? json['sigla_orgao']?.toString(),
        sit,
        json['descricao']?.toString() ??
            json['descricao_tramitacao']?.toString(),
        json['despacho']?.toString());
  }
}

class Proposal {
  final int id;
  final String identity;
  final String title;
  final DateTime? updatedAt;
  final StatusInfo status;

  Proposal(this.id, this.identity, this.title, this.updatedAt, this.status);

  factory Proposal.fromJson(Map<String, dynamic> json) => Proposal(
      json['id'],
      '${json['tipo']} ${json['numero']}/${json['ano']}',
      json['titulo'] ?? json['ementa'] ?? _unavailable,
      json['atualizado_em'] != null
          ? DateTime.tryParse(json['atualizado_em'])
          : null,
      StatusInfo.fromJson(json));
}

class ProposalPage {
  final List<Proposal> items;
  final int total;
  final int pages;

  ProposalPage(this.items, this.total, this.pages);

  factory ProposalPage.fromJson(Map<String, dynamic> json) {
    return ProposalPage(
        (json['items'] as List?)?.map((i) => Proposal.fromJson(i)).toList() ??
            [],
        (json['total'] is int)
            ? json['total']
            : int.tryParse(json['total']?.toString() ?? '0') ?? 0,
        (json['pages'] is int)
            ? json['pages']
            : int.tryParse(json['pages']?.toString() ?? '1') ?? 1);
  }
}

class ProposalDetail extends Proposal {
  final String? ementa;
  final DateTime? presentationDate;
  final String? lawType;
  final String? lawNumber;
  final int? lawYear;
  final DateTime? lawPublicationDate;
  final String? lawSource;
  final String? legalStatus;

  ProposalDetail(
      super.id,
      super.identity,
      super.title,
      super.updatedAt,
      super.status,
      this.ementa,
      this.presentationDate,
      this.lawType,
      this.lawNumber,
      this.lawYear,
      this.lawPublicationDate,
      this.lawSource,
      this.legalStatus);

  factory ProposalDetail.fromJson(Map<String, dynamic> json) {
    bool isVerificada = false;
    if (json['status'] is Map &&
        json['status']['vigencia_verificada'] == true) {
      isVerificada = true;
    }
    return ProposalDetail(
        json['id'],
        '${json['tipo']} ${json['numero']}/${json['ano']}',
        json['titulo'] ?? _unavailable,
        json['atualizado_em'] != null
            ? DateTime.tryParse(json['atualizado_em'])
            : null,
        StatusInfo.fromJson(json),
        json['ementa'],
        json['data_apresentacao'] != null
            ? DateTime.tryParse(json['data_apresentacao'])
            : null,
        json['lei_tipo'],
        json['lei_numero'],
        null,
        json['lei_data_publicacao'] != null
            ? DateTime.tryParse(json['lei_data_publicacao'])
            : null,
        json['lei_fonte_publicacao'],
        isVerificada ? "Verificada" : "Não Verificada");
  }
}

// API Service
class LegisApi {
  final Map<String, String> _headers = {
    'X-User-Id': _userId,
    'X-Admin-Token': _adminToken
  };

  Future<ProposalPage> proposals(
      {String? q, String? tipo, int? ano, String? status}) async {
    final queryParams = <String, String>{};
    if (q != null && q.isNotEmpty) queryParams['q'] = q;
    if (tipo != null && tipo.isNotEmpty) queryParams['tipo'] = tipo;
    if (ano != null) queryParams['ano'] = ano.toString();
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final uri = Uri.parse('$_baseUrl/proposicoes')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return ProposalPage.fromJson(jsonDecode(response.body));
    }
    throw Exception('Falha ao buscar proposições');
  }

  Future<ProposalPage> recent() async {
    final response =
        await http.get(Uri.parse('$_baseUrl/proposicoes'), headers: _headers);
    if (response.statusCode == 200) {
      return ProposalPage.fromJson(jsonDecode(response.body));
    }
    throw Exception('Falha ao buscar proposições recentes');
  }

  Future<ProposalDetail> getProposal(int id) async {
    final response = await http.get(Uri.parse('$_baseUrl/proposicoes/$id'),
        headers: _headers);
    if (response.statusCode == 200) {
      return ProposalDetail.fromJson(jsonDecode(response.body));
    }
    throw Exception('Falha ao obter detalhes');
  }

  Future<List<Author>> getAuthors(int id) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/proposicoes/$id/autores'), headers: _headers);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((j) => Author.fromJson(j))
          .toList();
    }
    throw Exception('Falha ao obter autores');
  }

  Future<List<Proceeding>> getProceedings(int id) async {
    final response = await http.get(
        Uri.parse('$_baseUrl/proposicoes/$id/tramitacoes'),
        headers: _headers);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((j) => Proceeding.fromJson(j))
          .toList();
    }
    throw Exception('Falha ao obter tramitações');
  }

  Future<bool> isFavorite(int id) async {
    try {
      final response =
          await http.get(Uri.parse('$_baseUrl/favoritos'), headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List list = [];

        // Se a API retornar uma lista direta [ {...} ]
        if (data is List) {
          list = data;
        }
        // Se a API retornar um objeto com paginação { "items": [ {...} ] }
        else if (data is Map) {
          list = data['items'] ?? data['data'] ?? data['favoritos'] ?? [];
        }

        // Varre a lista procurando o ID correto de forma segura
        return list.any((item) {
          final itemId = item['id'] ??
              item['proposicao_id'] ??
              item['id_projeto'] ??
              item['projeto_id'];
          return itemId?.toString() == id.toString();
        });
      }
    } catch (e) {
      debugPrint('Erro interno ao ler favoritos: $e');
    }
    return false; // Retorna falso se falhar a leitura
  }

  Future<void> addFavorite(int id) async {
    final headers = Map<String, String>.from(_headers)
      ..['Content-Type'] = 'application/json';

    final response = await http.post(
      Uri.parse('$_baseUrl/favoritos'),
      headers: headers,
      // CORREÇÃO AQUI: Mudamos de 'id_projeto' para 'proposicao_id'
      body: jsonEncode({'proposicao_id': id}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Erro do servidor (${response.statusCode}): ${response.body}');
    }
  }

  Future<void> removeFavorite(int id) async {
    final response = await http.delete(Uri.parse('$_baseUrl/favoritos/$id'),
        headers: _headers);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
          'Erro do servidor (${response.statusCode}): ${response.body}');
    }
  }
}

// App principal
void main() {
  runApp(const LegisApp());
}

class LegisApp extends StatelessWidget {
  const LegisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LEGIS',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0F172A),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8FE3CF),
          secondary: Color(0xFF2563EB),
          surface: Color(0xFF1E293B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final LegisApi api = LegisApi();

  void _openDetail(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProposalScreen(id: id, api: api)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(api: api, onOpen: _openDetail),
      SearchScreen(api: api, onOpen: _openDetail),
      const NotificationsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: const Color(0xFF8FE3CF),
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Explorar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications), label: 'Avisos'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final LegisApi api;
  final Function(int) onOpen;

  const HomeScreen({super.key, required this.api, required this.onOpen});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController controller = PageController();
  int page = 0;

  final content = [
    (
      'Bem-vindo ao LEGIS',
      'Sua plataforma independente para acompanhamento e auditoria de proposições legislativas na Câmara dos Deputados.'
    ),
    (
      'Acompanhe o que importa',
      'Receba alertas quando os projetos de lei que você segue tiverem movimentações e despachos reais.'
    ),
    (
      'Transparência total',
      'Dados processados diariamente da API pública (Dados Abertos), mapeados com histórico de tramitações.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 320,
          color: const Color(0xFF1E293B),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: controller,
                    itemCount: content.length,
                    onPageChanged: (v) => setState(() => page = v),
                    itemBuilder: (_, i) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon([Icons.search, Icons.timeline, Icons.bookmark][i],
                            size: 60, color: const Color(0xFF8FE3CF)),
                        const SizedBox(height: 22),
                        Text(content[i].$1,
                            style: const TextStyle(
                                fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(content[i].$2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    content.length,
                    (i) => Container(
                      margin: const EdgeInsets.all(4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: page == i
                              ? const Color(0xFF8FE3CF)
                              : Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        Expanded(
          child: ProposalListView(
            api: widget.api,
            onOpen: widget.onOpen,
            title: 'Recentes e Destaques',
            subtitle: 'Atualizações dos últimos dias',
            query: () => widget.api.recent(),
          ),
        ),
      ],
    );
  }
}

class ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorBox({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_errorTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: onRetry, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }
}

class EmptyBox extends StatelessWidget {
  final String message;
  const EmptyBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 60, color: Colors.white30),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class ProposalListView extends StatefulWidget {
  final LegisApi api;
  final Function(int) onOpen;
  final String title;
  final String subtitle;
  final Future<ProposalPage> Function() query;

  const ProposalListView(
      {super.key,
      required this.api,
      required this.onOpen,
      required this.title,
      required this.subtitle,
      required this.query});

  @override
  State<ProposalListView> createState() => _ProposalListViewState();
}

class _ProposalListViewState extends State<ProposalListView> {
  late Future<ProposalPage> future;

  @override
  void initState() {
    super.initState();
    future = widget.query();
  }

  void retry() => setState(() => future = widget.query());

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => retry(),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(widget.subtitle,
                      style: const TextStyle(color: Colors.white60)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: FutureBuilder<ProposalPage>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                        padding: EdgeInsets.all(44),
                        child: Center(child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    return ErrorBox(
                        message: snapshot.error.toString(), onRetry: retry);
                  }
                  final result = snapshot.data!;
                  if (result.items.isEmpty)
                    return const EmptyBox(
                        message: 'Nenhuma proposição encontrada.');
                  return Column(
                    children: result.items
                        .map((p) => ProposalCard(
                            item: p, onTap: () => widget.onOpen(p.id)))
                        .toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProposalCard extends StatelessWidget {
  final Proposal item;
  final VoidCallback onTap;

  const ProposalCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(item.identity,
                      style: const TextStyle(
                          color: Color(0xFF8FE3CF),
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  StatusChip(status: item.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                textOrUnavailable(item.title),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.update, size: 15, color: Colors.white54),
                  const SizedBox(width: 5),
                  Text('Atualizado: ${formatDateTime(item.updatedAt)}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final StatusInfo status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFF334155);
    Color fg = Colors.white;

    if (status.label == 'TRANSFORMADA_EM_NORMA') {
      bg = const Color(0xFF166534);
      fg = const Color(0xFF86EFAC);
    } else if (status.label == 'ARQUIVADA' || status.label == 'REJEITADA') {
      bg = const Color(0xFF7F1D1D);
      fg = const Color(0xFFFCA5A5);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status.rotulo,
          style:
              TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final Function(String?) onChanged;

  const _Dropdown(
      {required this.label,
      required this.value,
      required this.values,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      value: value,
      items: values
          .map((v) =>
              DropdownMenuItem(value: v, child: Text(v.isEmpty ? 'Todos' : v)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class SearchScreen extends StatefulWidget {
  final LegisApi api;
  final Function(int) onOpen;

  const SearchScreen({super.key, required this.api, required this.onOpen});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController q = TextEditingController();
  final TextEditingController year = TextEditingController();
  String type = '';
  String status = '';
  int searchVersion = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Explorar',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                TextField(
                  controller: q,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => setState(() => searchVersion++),
                  decoration: InputDecoration(
                      hintText: 'Buscar por número ou ementa',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                          onPressed: () => setState(() => searchVersion++),
                          icon: const Icon(Icons.arrow_forward)),
                      border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _Dropdown(
                          label: 'Tipo',
                          value: type,
                          values: const ['', 'PL', 'PLP', 'PEC'],
                          onChanged: (v) => setState(() {
                                type = v ?? '';
                                searchVersion++;
                              })),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: year,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Ano', border: OutlineInputBorder()),
                        onSubmitted: (_) => setState(() => searchVersion++),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(
                      labelText: 'Status', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Todos os status')),

                    // TODO: O filtro abaixo esta dando problema... por isso vou manter comentado temporariamente
                    // DropdownMenuItem(
                    //     value: 'FASE_INICIAL', child: Text('Fase Inicial')),

                    DropdownMenuItem(
                        value: 'EM_TRAMITACAO', child: Text('Em tramitação')),
                    DropdownMenuItem(
                        value: 'ARQUIVADA', child: Text('Arquivada')),
                    DropdownMenuItem(
                        value: 'TRANSFORMADA_EM_NORMA',
                        child: Text('Transformada em norma')),
                    DropdownMenuItem(
                        value: 'REJEITADA', child: Text('Rejeitada')),
                  ],
                  onChanged: (v) => setState(() {
                    status = v ?? '';
                    searchVersion++;
                  }),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(searchVersion),
            child: ProposalListView(
              api: widget.api,
              onOpen: widget.onOpen,
              title: 'Resultados',
              subtitle: 'Filtros enviados ao FastAPI',
              query: () => widget.api.proposals(
                  q: q.text,
                  tipo: type,
                  ano: int.tryParse(year.text),
                  status: status),
            ),
          ),
        ),
      ],
    );
  }
}

class ProposalScreen extends StatefulWidget {
  final int id;
  final LegisApi api;

  const ProposalScreen({super.key, required this.id, required this.api});

  @override
  State<ProposalScreen> createState() => _ProposalScreenState();
}

class _ProposalScreenState extends State<ProposalScreen> {
  late Future<ProposalDetail> detail;
  late Future<List<Author>> authors;
  late Future<List<Proceeding>> proceedings;
  bool favorite = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    detail = widget.api.getProposal(widget.id);
    authors = widget.api.getAuthors(widget.id);
    proceedings = widget.api.getProceedings(widget.id);
    widget.api.isFavorite(widget.id).then((v) {
      if (mounted) setState(() => favorite = v);
    });
  }

  void toggleFavorite() async {
    final nowFav = !favorite;
    setState(() => favorite = nowFav);
    try {
      if (nowFav) {
        await widget.api.addFavorite(widget.id);
      } else {
        await widget.api.removeFavorite(widget.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
        setState(() => favorite = !nowFav);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes')),
      body: FutureBuilder<ProposalDetail>(
        future: detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return ErrorBox(
                message: snapshot.error.toString(),
                onRetry: () => setState(_load));

          final p = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(p.identity,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF8FE3CF),
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(textOrUnavailable(p.title),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(status: p.status)),
              const SizedBox(height: 18),
              InfoSection(
                  title: 'Ementa',
                  child: Text(textOrUnavailable(p.ementa),
                      style: const TextStyle(height: 1.45))),
              InfoSection(
                title: 'Informações',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoLine(
                        label: 'Apresentação',
                        value: formatDate(p.presentationDate)),
                    InfoLine(
                        label: 'Atualização',
                        value: formatDateTime(p.updatedAt)),
                  ],
                ),
              ),
              if (p.lawNumber != null)
                InfoSection(
                  title: 'Norma relacionada',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InfoLine(
                          label: 'Norma',
                          value:
                              '${textOrUnavailable(p.lawType)} nº ${p.lawNumber}'),
                      InfoLine(
                          label: 'Publicação',
                          value: formatDate(p.lawPublicationDate)),
                      InfoLine(
                          label: 'Vigência',
                          value: textOrUnavailable(p.legalStatus)),
                      InfoLine(
                          label: 'Fonte',
                          value: textOrUnavailable(p.lawSource)),
                    ],
                  ),
                ),
              FilledButton.icon(
                onPressed: toggleFavorite,
                icon: Icon(favorite ? Icons.bookmark : Icons.bookmark_border),
                label: Text(favorite
                    ? 'Remover dos favoritos'
                    : 'Adicionar aos favoritos'),
              ),
              const SizedBox(height: 20),
              FutureBuilder<List<Author>>(
                future: authors,
                builder: (_, a) => InfoSection(
                  title: 'Autores',
                  child: a.connectionState == ConnectionState.waiting
                      ? const LinearProgressIndicator()
                      : a.hasError
                          ? Text(a.error.toString())
                          : a.data!.isEmpty
                              ? const Text(_unavailable)
                              : Column(
                                  children: a.data!
                                      .map((x) => ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(
                                                Icons.person_outline),
                                            title: Text(x.name),
                                            subtitle: Text(
                                                textOrUnavailable(x.type) +
                                                    (x.proponent
                                                        ? ' · Proponente'
                                                        : '')),
                                          ))
                                      .toList(),
                                ),
                ),
              ),
              FutureBuilder<List<Proceeding>>(
                future: proceedings,
                builder: (_, t) => InfoSection(
                  title: 'Tramitações',
                  child: t.connectionState == ConnectionState.waiting
                      ? const LinearProgressIndicator()
                      : t.hasError
                          ? Text(t.error.toString())
                          : t.data!.isEmpty
                              ? const Text(_unavailable)
                              : Column(
                                  children: t.data!
                                      .map((x) => ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(Icons.timeline),
                                            title: Text(
                                                textOrUnavailable(x.situation)),
                                            subtitle: Text(
                                                '${formatDateTime(x.date)} · ${textOrUnavailable(x.agency)}\n${textOrUnavailable(x.description)}${x.dispatch == null ? '' : '\nDespacho: ${x.dispatch}'}'),
                                          ))
                                      .toList(),
                                ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class InfoSection extends StatelessWidget {
  final String title;
  final Widget child;

  const InfoSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8FE3CF))),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const InfoLine({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 15, color: Colors.white),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(color: Colors.white70)),
            TextSpan(
                text: value,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none,
                  size: 68, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 18),
              const Text(
                'As notificações serão exibidas quando houver uma nova atualização em uma proposição',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, height: 1.4),
              ),
              const SizedBox(height: 12),
              const Text(
                'O envio real de notificações ainda não está implementado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<String, bool> values = {
    'Projetos Transformados em Norma': true,
    'Mudanças de Status em Projetos Seguidos': true,
    'Novos Despachos em Projetos Seguidos': false,
    'Resumo Semanal': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preferências')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Escolha os avisos de interesse. Estas opções funcionam apenas localmente e não enviam notificações.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          ...values.keys.map((key) => SwitchListTile(
                title: Text(key),
                value: values[key]!,
                onChanged: (v) => setState(() => values[key] = v),
              )),
        ],
      ),
    );
  }
}
