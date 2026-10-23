import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/legis_api.dart';

import '../../core/theme/app_theme.dart';
import '../../state/theme_controller.dart';

/// INTEGRAÇÃO BACK-END: aparência pode continuar local. Preferências de notificações
/// devem ser salvas na conta (GET/PATCH /usuarios/me/preferencias) e aplicadas também
/// no servidor que gera alertas. Diferenciar preferências locais das sincronizadas.


class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  Map<String, bool> _values = const {};
  bool _ready = false;
  String? _error;

  final List<_PreferenceOption> _options = const [
    _PreferenceOption(keyName: 'pref_novos_projetos', title: 'Novas proposições', description: 'Novas proposições que o ETL importar da API oficial.', enabled: true),
    _PreferenceOption(keyName: 'pref_atualizacoes', title: 'Tramitações dos favoritos', description: 'Novas tramitações oficiais em proposições que você favoritou.', enabled: true),
    _PreferenceOption(keyName: 'pref_votacoes', title: 'Votações em plenário', description: 'Indisponível: o ETL atual não coleta dados de votação.', enabled: false),
    _PreferenceOption(keyName: 'pref_outras', title: 'Comunicados gerais', description: 'Indisponível: não há fonte ou serviço de comunicados configurado.', enabled: false),
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final api = context.read<LegisApi>();
      final loaded = await api.getPreferences();
      if (!mounted) return;
      // Salva defaults da conta antiga se ainda não havia um mapa no banco.
      final persisted = await api.updatePreferences(loaded);
      if (!mounted) return;
      setState(() { _values = persisted; _ready = true; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _ready = true; });
    }
  }

  Future<void> _update(String key, bool value) async {
    final previous = _values[key] ?? false;
    setState(() { _values = {..._values, key: value}; _error = null; });
    try {
      final updated = await context.read<LegisApi>().updatePreferences({key: value});
      if (mounted) setState(() => _values = updated);
    } catch (error) {
      if (mounted) setState(() { _values = {..._values, key: previous}; _error = error.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back)),
        title: const Text('Preferências'),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 25),
                  children: [
                    Text('Preferências', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 7),
                    Text(
                      'Selecione quais tipos de notificações deseja receber do LEGIS.',
                      style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.4),
                    ),
                    const SizedBox(height: 17),
                    Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Aparência', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 5),
                      Text('Escolha o tema do aplicativo.', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 10),
                      Consumer<ThemeController>(builder: (context, controller, _) => Column(children: [
                        RadioListTile<ThemeMode>(value: ThemeMode.light, groupValue: controller.mode, onChanged: (mode) { if (mode != null) controller.setMode(mode); }, title: const Text('Modo claro')),
                        RadioListTile<ThemeMode>(value: ThemeMode.dark, groupValue: controller.mode, onChanged: (mode) { if (mode != null) controller.setMode(mode); }, title: const Text('Modo escuro')),
                        RadioListTile<ThemeMode>(value: ThemeMode.system, groupValue: controller.mode, onChanged: (mode) { if (mode != null) controller.setMode(mode); }, title: const Text('Seguir o sistema do celular')),
                      ])),
                    ]))),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 17, color: c.accent),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'As opções compatíveis são salvas na sua conta. Os avisos in-app surgem após a sincronização do ETL; notificações push ainda não existem.',
                              style: TextStyle(color: c.onAccentSoft, fontSize: 11.5, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: TextStyle(color: c.danger))),
                    ..._options.map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: SwitchListTile.adaptive(
                            value: _values[option.keyName] ?? false,
                            onChanged: option.enabled ? (value) => _update(option.keyName, value) : null,
                            contentPadding: const EdgeInsets.fromLTRB(14, 7, 11, 7),
                            title: Text(option.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(option.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5, height: 1.35)),
                            ),
                          ),
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

class _PreferenceOption {
  const _PreferenceOption({required this.keyName, required this.title, required this.description, required this.enabled});
  final String keyName;
  final String title;
  final String description;
  final bool enabled;
}
