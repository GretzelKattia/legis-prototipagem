import 'package:intl/intl.dart';

class PropositionStatus {
  const PropositionStatus({
    this.codigo = '',
    this.rotulo = 'Status não informado',
    this.detalhe,
    this.vigenciaVerificada = false,
  });

  final String codigo;
  final String rotulo;
  final String? detalhe;
  final bool vigenciaVerificada;

  factory PropositionStatus.fromJson(dynamic value) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final code = '${map['codigo'] ?? map['codigo_situacao_api'] ?? ''}';
      final rawLabel = map['rotulo'] ?? map['label'] ?? map['descricao'] ?? map['descricao_situacao_api'];
      return PropositionStatus(
        codigo: code,
        rotulo: _statusLabel(rawLabel?.toString(), code),
        detalhe: _nullableString(map['detalhe'] ?? map['lei_detalhe']),
        vigenciaVerificada: map['vigencia_verificada'] == true || map['vigenciaVerificada'] == true,
      );
    }
    final raw = value?.toString() ?? '';
    return PropositionStatus(codigo: raw, rotulo: _statusLabel(raw, raw));
  }

  static String _statusLabel(String? label, String code) {
    final candidate = (label ?? '').trim();
    if (candidate.isNotEmpty && candidate.toLowerCase() != 'null') {
      final upper = candidate.toUpperCase();
      if (upper == 'TRANSFORMADO_EM_NORMA' || upper == 'TRANSFORMADA_EM_NORMA') return 'Transformada em Norma';
      if (upper == 'EM_TRAMITACAO') return 'Em tramitação';
      if (upper == 'EM_DISCUSAO' || upper == 'EM_DISCUSSÃO' || upper == 'EM_DISCussao'.toUpperCase()) return 'Em discussão';
      return candidate;
    }
    switch (code.toUpperCase()) {
      case '1140':
      case 'TRANSFORMADA_EM_NORMA':
      case 'TRANSFORMADO_EM_NORMA':
        return 'Transformada em Norma';
      case '924':
        return 'Pronta para pauta';
      case '926':
        return 'Aguardando Senado';
      case 'EM_TRAMITACAO':
        return 'Em tramitação';
      case 'EM_DISCUSAO':
        return 'Em discussão';
      case 'ARQUIVADA':
        return 'Arquivada';
      default:
        return 'Status não informado';
    }
  }
}

class Proposition {
  const Proposition({
    required this.id,
    this.tipo = '',
    this.numero = '',
    this.ano = 0,
    this.titulo = '',
    this.ementa,
    this.dataApresentacao,
    this.status = const PropositionStatus(),
    this.atualizadoEm,
    this.leiNumero,
    this.leiTipo,
    this.leiDataPublicacao,
    this.autorNome,
  });

  final int id;
  final String tipo;
  final String numero;
  final int ano;
  final String titulo;
  final String? ementa;
  final String? dataApresentacao;
  final PropositionStatus status;
  final String? atualizadoEm;
  final String? leiNumero;
  final String? leiTipo;
  final String? leiDataPublicacao;
  final String? autorNome;

  String get updatedLabel => _formatDate(atualizadoEm) ?? 'não informado';
  String get presentationDateLabel => _formatDate(dataApresentacao) ?? 'Informação não disponível';

  factory Proposition.fromJson(Map<String, dynamic> json) {
    final nested = json['proposicao'];
    final map = nested is Map ? Map<String, dynamic>.from(nested) : json;
    final rawStatus = map['status'] ?? map['situacao'] ?? map['descricao_situacao_api'] ?? map['codigo_situacao_api'];
    final title = map['titulo'] ?? map['ementa'] ?? map['nome'] ?? map['descricao'];
    final authors = map['autores'];
    String? author;
    if (authors is List && authors.isNotEmpty && authors.first is Map) {
      author = _nullableString(authors.first['nome']?.toString());
    }
    final idValue = map['id'] ?? map['id_projeto'] ?? map['proposicao_id'] ?? map['idProposicao'];
    return Proposition(
      id: _asInt(idValue),
      tipo: (map['tipo'] ?? map['sigla_tipo'] ?? map['siglaTipo'] ?? map['sigla_tipo_proposicao'] ?? '').toString(),
      numero: (map['numero'] ?? map['numero_pl'] ?? '').toString(),
      ano: _asInt(map['ano']),
      titulo: title?.toString() ?? '',
      ementa: _nullableString(map['ementa']?.toString()),
      dataApresentacao: _nullableString((map['data_apresentacao'] ?? map['dataApresentacao'])?.toString()),
      status: PropositionStatus.fromJson(rawStatus is Map ? rawStatus : rawStatus),
      atualizadoEm: _nullableString((map['atualizado_em'] ?? map['atualizada_em'] ?? map['updated_at'])?.toString()),
      leiNumero: _nullableString((map['lei_numero'] ?? map['leiNumero'])?.toString()),
      leiTipo: _nullableString((map['lei_tipo'] ?? map['leiTipo'])?.toString()),
      leiDataPublicacao: _nullableString((map['lei_data_publicacao'] ?? map['leiDataPublicacao'])?.toString()),
      autorNome: author ?? _nullableString((map['autor'] ?? map['nome_autor'])?.toString()),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return text;
}

String? _formatDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('dd/MM/yyyy').format(parsed.toLocal());
}
