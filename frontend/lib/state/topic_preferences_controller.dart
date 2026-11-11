import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/proposition.dart';

class TopicCatalog {
  TopicCatalog._();

  static const topics = <String>[
    'Educação',
    'Saúde',
    'Meio ambiente',
    'Segurança pública',
    'Economia',
    'Direitos humanos',
    'Trabalho',
    'Tecnologia e inovação',
    'Infraestrutura',
    'Justiça e cidadania',
  ];

  static const _keywords = <String, List<String>>{
    'Educação': ['educação', 'escola', 'ensino', 'universidade', 'professor', 'estudante', 'aprendizagem', 'merenda'],
    'Saúde': ['saúde', 'hospital', 'sus', 'médico', 'medicina', 'doença', 'vacina', 'farmácia', 'paciente'],
    'Meio ambiente': ['meio ambiente', 'ambiental', 'clima', 'floresta', 'água', 'sustentável', 'sustentabilidade', 'resíduo', 'poluição'],
    'Segurança pública': ['segurança pública', 'polícia', 'penal', 'crime', 'criminal', 'violência', 'arma', 'presídio', 'segurança'],
    'Economia': ['economia', 'econômico', 'financeiro', 'tributário', 'imposto', 'orçamento', 'crédito', 'mercado', 'inflação'],
    'Direitos humanos': ['direitos humanos', 'igualdade', 'discriminação', 'racismo', 'mulher', 'idoso', 'criança', 'pessoa com deficiência', 'minoria'],
    'Trabalho': ['trabalho', 'trabalhista', 'emprego', 'salário', 'aposentadoria', 'previdência', 'sindicato', 'jornada'],
    'Tecnologia e inovação': ['tecnologia', 'inovação', 'internet', 'digital', 'dados', 'inteligência artificial', 'software', 'ciência'],
    'Infraestrutura': ['infraestrutura', 'transporte', 'rodovia', 'ferrovia', 'mobilidade', 'habitação', 'saneamento', 'energia', 'logística'],
    'Justiça e cidadania': ['justiça', 'cidadania', 'constitucional', 'judicial', 'processo', 'eleitoral', 'lei', 'direito'],
  };

  static bool matches(Proposition proposition, Iterable<String> selectedTopics) {
    final topics = selectedTopics.toSet();
    if (topics.isEmpty) return false;
    final searchable = '${proposition.titulo} ${proposition.ementa ?? ''} ${proposition.autorNome ?? ''}'.toLowerCase();
    return topics.any((topic) => (_keywords[topic] ?? const []).any(searchable.contains));
  }

  static List<String> matchedTopics(Proposition proposition, Iterable<String> selectedTopics) {
    final searchable = '${proposition.titulo} ${proposition.ementa ?? ''} ${proposition.autorNome ?? ''}'.toLowerCase();
    return selectedTopics.where((topic) => (_keywords[topic] ?? const []).any(searchable.contains)).toList();
  }
}

class TopicPreferencesController extends ChangeNotifier {
  static const _storageKey = 'legis_topics_of_interest';
  Set<String> _selected = <String>{};
  bool _loaded = false;

  List<String> get selectedTopics => _selected.toList(growable: false);
  bool get loaded => _loaded;
  bool isSelected(String topic) => _selected.contains(topic);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_storageKey) ?? const <String>[];
    _selected = saved.where(TopicCatalog.topics.contains).toSet();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setSelected(String topic, bool selected) async {
    if (selected) {
      _selected.add(topic);
    } else {
      _selected.remove(topic);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, _selected.toList()..sort());
  }

  bool matches(Proposition proposition) => TopicCatalog.matches(proposition, _selected);
}
