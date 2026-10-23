import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/legis_notification.dart';
import '../../services/legis_api.dart';
import '../details/proposition_detail_screen.dart';

/// INTEGRAÇÃO BACK-END: carregar detalhe por ID da notificação e obter a proposição
/// associada quando houver. Marcar como lida no servidor (PATCH/PUT de leitura) e tratar
/// notificações sem proposição vinculada ou cujo conteúdo já não esteja disponível.


class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({super.key, required this.notification});
  final LegisNotification notification;

  @override
  State<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  bool _opening = false;

  Future<void> _openProposition() async {
    final id = widget.notification.propositionId;
    if (id == null || _opening) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<LegisApi>();
    setState(() => _opening = true);
    try {
      final proposition = await api.getProposition(id);
      if (!mounted) return;
      await navigator.push(MaterialPageRoute(builder: (_) => PropositionDetailScreen(proposition: proposition)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Não foi possível abrir a proposição. $error')));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    final item = widget.notification;
    final hasProposition = item.propositionId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Notificação')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: c.hero,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(13)),
                      child: Icon(item.icon, color: AppColors.offWhite, size: 23),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: TextStyle(color: c.onHero, fontSize: 18, fontWeight: FontWeight.w700, height: 1.3)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 14, color: AppColors.tealTint),
                              const SizedBox(width: 6),
                              Text(item.dateTimeLabel, style: const TextStyle(color: AppColors.tealTint, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Conteúdo', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Text(item.content, style: TextStyle(color: c.text, fontSize: 14, height: 1.6)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (hasProposition)
                FilledButton.icon(
                  onPressed: _opening ? null : _openProposition,
                  icon: _opening
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.onAction))
                      : const Icon(Icons.article_outlined),
                  label: const Text('Ver proposição relacionada'),
                )
              else
                Text('Esta notificação não possui uma proposição relacionada.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
