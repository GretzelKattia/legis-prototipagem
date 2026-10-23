import '../core/network/api_client.dart';
import '../models/author.dart';
import '../models/proposition.dart';
import '../models/tramitation.dart';
import '../models/legis_notification.dart';

/// Acesso exclusivo à API FastAPI. Dados legislativos nunca são sintetizados pelo app.

class PropositionPage {
  const PropositionPage({required this.items, required this.page, required this.totalPages});
  final List<Proposition> items;
  final int page;
  final int totalPages;
  bool get hasMore => page < totalPages;
}

class LegisApi {
  LegisApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> register({required String name, required String email, required String password}) async {
    final result = await _client.post('/auth/register', body: {'nome': name.trim(), 'email': email.trim(), 'senha': password});
    if (result is! Map) throw Exception('Resposta inválida ao criar a conta.');
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    final result = await _client.post('/auth/login', body: {'email': email.trim(), 'senha': password});
    if (result is! Map) throw Exception('Resposta inválida ao autenticar.');
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _client.get('/auth/me');
    if (response is! Map) throw Exception('Resposta inválida ao carregar a conta.');
    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> updateProfile({required String name, required String email}) async {
    final result = await _client.patch('/auth/me', body: {'nome': name.trim(), 'email': email.trim()});
    if (result is! Map) throw Exception('Resposta inválida ao atualizar o perfil.');
    return Map<String, dynamic>.from(result);
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _client.post('/auth/change-password', body: {'senha_atual': currentPassword, 'nova_senha': newPassword});
  }

  Future<void> logout() async { await _client.post('/auth/logout'); }

  Future<Map<String, bool>> getPreferences() async {
    final response = await _client.get('/usuarios/me/preferencias');
    if (response is! Map || response['preferencias'] is! Map) throw Exception('Resposta inválida ao carregar preferências.');
    return Map<String, dynamic>.from(response['preferencias'] as Map).map((key, value) => MapEntry(key, value == true));
  }

  Future<Map<String, bool>> updatePreferences(Map<String, bool> preferences) async {
    final response = await _client.patch('/usuarios/me/preferencias', body: {'preferencias': preferences});
    if (response is! Map || response['preferencias'] is! Map) throw Exception('Resposta inválida ao salvar preferências.');
    return Map<String, dynamic>.from(response['preferencias'] as Map).map((key, value) => MapEntry(key, value == true));
  }

  Future<List<LegisNotification>> getNotifications() async {
    final all = <LegisNotification>[];
    var page = 1;
    var totalPages = 1;
    do {
      final response = await _client.get('/notificacoes', query: {'page': '$page', 'per_page': '100'});
      final root = response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
      all.addAll(_items(response, ['items']).whereType<Map>().map((raw) => LegisNotification.fromJson(Map<String, dynamic>.from(raw))));
      final meta = root['meta'] is Map ? Map<String, dynamic>.from(root['meta']) : <String, dynamic>{};
      totalPages = _int(meta['total_paginas'] ?? meta['total_pages'], page);
      page++;
    } while (page <= totalPages);
    return all;
  }

  Future<void> markNotificationRead(int id) async { await _client.patch('/notificacoes/$id/lida'); }

  Future<PropositionPage> getPropositions({
    String? query,
    String? tipo,
    String? ano,
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, String>{'page': '$page', 'per_page': '$perPage'};
    if (query != null && query.trim().isNotEmpty) params['q'] = query.trim();
    if (tipo != null && tipo.isNotEmpty) params['tipo'] = tipo;
    if (ano != null && ano.trim().isNotEmpty) params['ano'] = ano.trim();
    if (status != null && status.isNotEmpty) params['status'] = status;
    final response = await _client.get('/proposicoes', query: params);
    final root = response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
    final rawItems = _items(response, ['items', 'results', 'proposicoes', 'data']);
    final items = rawItems.whereType<Map>().map((e) => Proposition.fromJson(Map<String, dynamic>.from(e))).toList();
    final meta = root['meta'] is Map ? Map<String, dynamic>.from(root['meta']) : <String, dynamic>{};
    final current = _int(meta['pagina'] ?? meta['page'], page);
    final totalPages = _int(meta['total_paginas'] ?? meta['total_pages'], current == 1 && items.length < perPage ? 1 : current + (items.length == perPage ? 1 : 0));
    return PropositionPage(items: items, page: current, totalPages: totalPages < current ? current : totalPages);
  }

  Future<Proposition> getProposition(int id) async {
    final response = await _client.get('/proposicoes/$id');
    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      final nested = map['item'] ?? map['proposicao'] ?? map['data'];
      if (nested is Map) return Proposition.fromJson(Map<String, dynamic>.from(nested));
      return Proposition.fromJson(map);
    }
    throw Exception('Resposta inválida ao carregar a proposição.');
  }

  Future<List<Author>> getAuthors(int id) async {
    final response = await _client.get('/proposicoes/$id/autores');
    return _items(response, ['items', 'autores', 'data'])
        .whereType<Map>()
        .map((e) => Author.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Tramitation>> getTramitations(int id) async {
    dynamic response;
    try {
      response = await _client.get('/proposicoes/$id/tramitacoes');
    } catch (_) {
      response = await _client.get('/proposicoes/$id/linha-do-tempo');
    }
    return _items(response, ['items', 'tramitacoes', 'tramitações', 'linha_do_tempo', 'data'])
        .whereType<Map>()
        .map((e) => Tramitation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Proposition>> getFavorites() async {
    final all = <Proposition>[];
    var page = 1;
    var totalPages = 1;
    do {
      final response = await _client.get('/favoritos', query: {'page': '$page', 'per_page': '100'});
      final root = response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
      all.addAll(_items(response, ['items', 'favoritos', 'results', 'data'])
          .whereType<Map>()
          .map((raw) {
            final item = Map<String, dynamic>.from(raw);
            final nested = item['proposicao'] ?? item['proposition'];
            if (nested is Map) return Proposition.fromJson(Map<String, dynamic>.from(nested));
            return Proposition.fromJson(item);
          })
          .where((item) => item.id > 0));
      final meta = root['meta'] is Map ? Map<String, dynamic>.from(root['meta']) : <String, dynamic>{};
      totalPages = _int(meta['total_paginas'] ?? meta['total_pages'], page);
      page++;
    } while (page <= totalPages);
    return all;
  }

  Future<void> addFavorite(int propositionId) async {
    await _client.post(
      '/favoritos',
      body: {'proposicao_id': propositionId},
    );
  }

  Future<void> removeFavorite(int propositionId) async {
    await _client.delete(
      '/favoritos/$propositionId',
    );
  }

  static List<dynamic> _items(dynamic data, List<String> keys) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in keys) {
        if (data[key] is List) return data[key] as List<dynamic>;
      }
    }
    return const [];
  }

  static int _int(dynamic value, int fallback) => int.tryParse('$value') ?? fallback;
}
