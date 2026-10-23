class Author {
  const Author({required this.nome, this.tipo, this.proponente = false});

  final String nome;
  final String? tipo;
  final bool proponente;

  factory Author.fromJson(Map<String, dynamic> json) => Author(
        nome: (json['nome'] ?? json['nome_autor'] ?? 'Informação não disponível').toString(),
        tipo: _asNullable(json['tipo'] ?? json['tipo_autor']),
        proponente: json['proponente'] == true,
      );
}

String? _asNullable(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty || text.toLowerCase() == 'null' ? null : text;
}
