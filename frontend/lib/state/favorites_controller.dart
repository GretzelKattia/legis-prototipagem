import 'package:flutter/foundation.dart';

import '../models/proposition.dart';
import '../services/legis_api.dart';

/// Estado global dos favoritos.
///
/// A alternância é **otimista**: o estado muda e a interface é redesenhada
/// imediatamente (ícone, rótulo, AppBar, rodapé e cards); a chamada à API roda
/// em seguida e, se falhar, o estado anterior é restaurado e o erro é repassado.
class FavoritesController extends ChangeNotifier {
  FavoritesController(this._api);
  final LegisApi _api;

  final Map<int, Proposition> _items = {};
  final Set<int> _busyIds = {};
  bool _loading = false;
  String? _error;

  List<Proposition> get items => _items.values.toList(growable: false);
  bool get isLoading => _loading;
  String? get error => _error;
  bool isFavorite(int id) => _items.containsKey(id);
  bool isBusy(int id) => _busyIds.contains(id);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.getFavorites();
      _items
        ..clear()
        ..addEntries(result.map((item) => MapEntry(item.id, item)));
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> toggle(Proposition proposition) async {
    final id = proposition.id;
    if (id <= 0 || _busyIds.contains(id)) return;

    final previous = _items[id];
    final wasFavorite = previous != null;

    // 1) Atualização imediata da interface.
    _busyIds.add(id);
    if (wasFavorite) {
      _items.remove(id);
    } else {
      _items[id] = proposition;
    }
    notifyListeners();

    // 2) Persistência; em caso de falha, desfaz.
    try {
      if (wasFavorite) {
        await _api.removeFavorite(id);
      } else {
        await _api.addFavorite(id);
      }
      _error = null;
    } catch (_) {
      if (wasFavorite) {
        _items[id] = previous!;
      } else {
        _items.remove(id);
      }
      rethrow;
    } finally {
      _busyIds.remove(id);
      notifyListeners();
    }
  }
}
