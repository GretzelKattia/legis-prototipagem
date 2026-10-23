import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/proposition.dart';
import '../../state/favorites_controller.dart';
import '../theme/app_theme.dart';

/// Alterna o favorito e mostra uma mensagem em caso de erro.
/// Com [showConfirmation], também confirma o resultado em um SnackBar.
Future<void> toggleFavoriteWithFeedback(
  BuildContext context,
  Proposition proposition, {
  bool showConfirmation = false,
}) async {
  final controller = context.read<FavoritesController>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    await controller.toggle(proposition);
    if (showConfirmation) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(controller.isFavorite(proposition.id) ? 'Adicionado aos favoritos.' : 'Removido dos favoritos.'),
      ));
    }
  } catch (error) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text('Não foi possível atualizar os favoritos. $error')));
  }
}

/// Ícone de favoritar reativo: observa apenas o estado desta proposição.
///  - não favorita: Icons.bookmark_border (vazado)
///  - favorita: Icons.bookmark (preenchido em bronze)
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.proposition,
    this.onDark = false,
    this.showConfirmation = false,
  });

  final Proposition proposition;

  /// Use `true` sobre fundos azul-noturno (ex.: AppBar).
  final bool onDark;
  final bool showConfirmation;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final isFavorite = context.select<FavoritesController, bool>((f) => f.isFavorite(proposition.id));

    final activeColor = onDark ? AppColors.tealLight : c.accent;
    final idleColor = onDark ? AppColors.offWhite : c.textSecondary;

    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      tooltip: isFavorite ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
      onPressed: () => toggleFavoriteWithFeedback(context, proposition, showConfirmation: showConfirmation),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
        child: Icon(
          isFavorite ? Icons.bookmark : Icons.bookmark_border,
          key: ValueKey<bool>(isFavorite),
          color: isFavorite ? activeColor : idleColor,
        ),
      ),
    );
  }
}
