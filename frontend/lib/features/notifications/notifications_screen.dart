import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/legis_header.dart';
import '../../models/legis_notification.dart';
import '../../services/legis_api.dart';
import '../preferences/preferences_screen.dart';
import 'notification_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<LegisNotification> _items = const [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await context.read<LegisApi>().getNotifications();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(LegisNotification item) async {
    if (!item.isRead) {
      try {
        await context.read<LegisApi>().markNotificationRead(item.id);
        if (mounted) setState(() {
          _items = _items.map((n) => n.id == item.id ? n.copyWith(isRead: true) : n).toList();
        });
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível marcar como lida: $error')));
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotificationDetailScreen(notification: item.copyWith(isRead: true))));
  }

  Future<void> _openPreferences() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PreferencesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return Scaffold(
      appBar: LegisHeader(onPreferences: _openPreferences),
      body: Align(alignment: Alignment.topCenter, child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: _loading && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _items.isEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.cloud_off_outlined, color: c.textSecondary, size: 32),
                    const SizedBox(height: 12), Text('Não foi possível carregar as notificações', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8), Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                    TextButton(onPressed: _load, child: const Text('Tentar novamente')),
                  ])))
                : RefreshIndicator(onRefresh: _load, child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 25),
                    children: [
                      Text('Notificações', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text('Avisos gerados após a sincronização de dados oficiais da Câmara.', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 14),
                      if (_items.isEmpty)
                        Padding(padding: const EdgeInsets.symmetric(vertical: 50), child: Column(children: [
                          Icon(Icons.notifications_none_rounded, color: c.textSecondary, size: 38),
                          const SizedBox(height: 12), Text('Nenhuma notificação disponível.', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6), Text('Novos avisos só aparecem quando o ETL registra proposições ou tramitações e suas preferências permitem.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                        ]))
                      else ..._items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(child: InkWell(
                          borderRadius: BorderRadius.circular(17), onTap: () => _open(item),
                          child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(width: 38, height: 38, decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)), child: Icon(item.icon, color: c.accent, size: 19)),
                            const SizedBox(width: 11),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [Expanded(child: Text(item.title, style: TextStyle(color: c.text, fontWeight: FontWeight.w700, fontSize: 13))), if (!item.isRead) Container(width: 8, height: 8, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle))]),
                              if (item.summary.isNotEmpty) ...[const SizedBox(height: 5), Text(item.summary, style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.4))],
                              const SizedBox(height: 7), Text(item.dateTimeLabel, style: TextStyle(color: c.accentText, fontSize: 11, fontWeight: FontWeight.w600)),
                            ])),
                            const SizedBox(width: 4), Padding(padding: const EdgeInsets.only(top: 9), child: Icon(Icons.chevron_right_rounded, color: c.textSecondary, size: 20)),
                          ])),
                        )),
                      )),
                      if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: TextStyle(color: c.danger))),
                    ],
                  )),
      )),
    );
  }
}
