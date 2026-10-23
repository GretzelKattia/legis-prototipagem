import 'package:intl/intl.dart';

class Tramitation {
  const Tramitation({
    this.dataHora,
    this.orgao,
    this.situacao,
    this.descricao,
    this.despacho,
    this.sequencia = 0,
  });

  final String? dataHora;
  final String? orgao;
  final String? situacao;
  final String? descricao;
  final String? despacho;
  final int sequencia;

  String get dataLabel {
    if (dataHora == null || dataHora!.isEmpty) return 'Data não disponível';
    final date = DateTime.tryParse(dataHora!);
    return date == null ? 'Data não disponível' : DateFormat('dd/MM/yyyy').format(date.toLocal());
  }

  factory Tramitation.fromJson(Map<String, dynamic> json) => Tramitation(
        dataHora: _nullable(json['data_hora'] ?? json['dataHora']),
        orgao: _nullable(json['orgao'] ?? json['siglaOrgao']),
        situacao: _nullable(json['situacao'] ?? json['situacao_descricao']),
        descricao: _nullable(json['descricao'] ?? json['descricao_tramitacao']),
        despacho: _nullable(json['despacho']),
        sequencia: int.tryParse('${json['sequencia'] ?? 0}') ?? 0,
      );
}

String? _nullable(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
}
