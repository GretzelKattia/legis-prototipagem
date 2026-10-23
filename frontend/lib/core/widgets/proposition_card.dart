import 'package:flutter/material.dart';

import '../../features/details/proposition_detail_screen.dart';
import '../../models/proposition.dart';
import '../theme/app_theme.dart';
import 'favorite_button.dart';
import 'status_badge.dart';

class PropositionCard extends StatelessWidget {
  const PropositionCard({super.key, required this.proposition});

  final Proposition proposition;

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final code = proposition.tipo.isEmpty ? 'Proposição' : proposition.tipo;
    final identification = proposition.numero.isNotEmpty && proposition.ano > 0
        ? '$code ${proposition.numero}/${proposition.ano}'
        : (proposition.id > 0 ? '$code • ${proposition.id}' : code);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PropositionDetailScreen(proposition: proposition)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 10, 8, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      identification,
                      style: TextStyle(color: c.accentText, fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                  FavoriteButton(proposition: proposition),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proposition.titulo.isNotEmpty ? proposition.titulo : 'Informação não disponível',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w700, height: 1.35),
                    ),
                    if (proposition.autorNome != null && proposition.autorNome!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 14, color: c.textSecondary),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              proposition.autorNome!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: c.textSecondary, fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBadge(label: proposition.status.rotulo),
                        if (proposition.status.detalhe != null && proposition.status.detalhe!.isNotEmpty)
                          Text(
                            proposition.status.detalhe!,
                            style: TextStyle(color: c.textSecondary, fontSize: 11),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.update_rounded, size: 13, color: c.textSecondary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Atualizado em ${proposition.updatedLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.textSecondary, fontSize: 10.5),
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 18, color: c.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
