import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LegisNotification {
  const LegisNotification({
    required this.id,
    required this.icon,
    required this.title,
    required this.summary,
    required this.content,
    required this.dateTime,
    this.propositionId,
    this.isRead = false,
  });

  final int id;
  final IconData icon;
  final String title;

  /// Texto curto exibido no card da lista.
  final String summary;

  /// Texto completo exibido na tela de detalhes.
  final String content;
  final DateTime dateTime;

  /// Proposição relacionada (quando houver).
  final int? propositionId;
  final bool isRead;

  LegisNotification copyWith({bool? isRead}) => LegisNotification(
    id: id, icon: icon, title: title, summary: summary, content: content,
    dateTime: dateTime, propositionId: propositionId, isRead: isRead ?? this.isRead,
  );

  factory LegisNotification.fromJson(Map<String, dynamic> json) {
    final id = int.tryParse('${json['id'] ?? 0}') ?? 0;
    final propositionId = int.tryParse('${json['proposicao_id'] ?? 0}');
    final type = '${json['tipo_evento'] ?? ''}';
    final title = '${json['titulo'] ?? ''}';
    final description = '${json['descricao'] ?? ''}'.trim();
    return LegisNotification(
      id: id,
      icon: type == 'NOVA_PROPOSICAO' ? Icons.library_books_outlined : Icons.update_rounded,
      title: title,
      summary: description,
      content: description,
      dateTime: DateTime.tryParse('${json['criada_em'] ?? ''}')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
      propositionId: propositionId == 0 ? null : propositionId,
      isRead: json['lida_em'] != null,
    );
  }

  String get dateTimeLabel => dateTime.millisecondsSinceEpoch == 0 ? 'Data não informada' : DateFormat("dd/MM/yyyy 'às' HH:mm").format(dateTime);
}
