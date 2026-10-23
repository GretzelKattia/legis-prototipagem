import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_state_views.dart';
import '../../core/widgets/legis_header.dart';
import '../../core/widgets/proposition_card.dart';
import '../../state/favorites_controller.dart';
import '../preferences/preferences_screen.dart';

/// INTEGRAÇÃO BACK-END: buscar favoritos do usuário autenticado (GET /favoritos),
/// com paginação e estados de carregamento/erro/vazio. Adicionar/remover deve chamar
/// POST/DELETE da API e atualizar a interface apenas após resposta confirmada.


class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  Future<void> _openPreferences(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PreferencesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LegisHeader(onPreferences: () => _openPreferences(context)),
      body: Consumer<FavoritesController>(
        builder: (context, favorites, _) {
          if (favorites.isLoading && favorites.items.isEmpty) return const LoadingView(label: 'Carregando favoritos...');
          if (favorites.error != null && favorites.items.isEmpty) {
            return EmptyView(icon: Icons.cloud_off_outlined, title: 'Não foi possível carregar seus favoritos.', description: favorites.error, actionLabel: 'Tentar novamente', onAction: favorites.load);
          }
          if (favorites.items.isEmpty) return const EmptyView(icon: Icons.bookmark_border_rounded, title: 'Você ainda não favoritou nenhuma proposição.', description: 'Toque no marcador de um card para salvar uma proposição.');
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: RefreshIndicator(
                onRefresh: favorites.load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 25),
                  children: [
                    Text('Meus favoritos', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 5),
                    Text('${favorites.items.length} proposição(ões) salvas', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    ...favorites.items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 11), child: PropositionCard(proposition: item))),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
