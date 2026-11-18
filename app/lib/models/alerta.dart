import 'registro_campo.dart';

/// Identifica qual regra de negócio disparou automaticamente o alerta.
enum RegraAlerta {
  umidadeBaixa('umidade_baixa', 'Umidade Abaixo do Limite'),
  ocorrenciaPragaDoenca('ocorrencia_praga_doenca', 'Praga ou Doença'),
  proximidadeColheita('proximidade_colheita', 'Proximidade da Colheita'),
  colheitaAtrasada('colheita_atrasada', 'Colheita em Atraso');

  const RegraAlerta(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static RegraAlerta fromApiValue(String? value) {
    return RegraAlerta.values.firstWhere(
      (r) => r.apiValue == value,
      orElse: () => RegraAlerta.umidadeBaixa,
    );
  }
}

/// Alerta gerado automaticamente a partir dos dados reais de um talhão.
class Alerta {
  const Alerta({
    required this.id,
    required this.talhaoId,
    required this.propriedadeId,
    required this.regra,
    required this.severidade,
    required this.titulo,
    required this.mensagem,
    required this.parametroDisparo,
    required this.ativo,
    required this.criadoEm,
    this.resolvidoEm,
    this.resolvidoPor,
  });

  final String id;
  final String talhaoId;
  final String propriedadeId;
  final RegraAlerta regra;
  final Severidade severidade;
  final String titulo;
  final String mensagem;
  final String parametroDisparo;
  final bool ativo;
  final DateTime criadoEm;
  final DateTime? resolvidoEm;
  final String? resolvidoPor;

  Alerta copyWith({
    String? id,
    String? talhaoId,
    String? propriedadeId,
    RegraAlerta? regra,
    Severidade? severidade,
    String? titulo,
    String? mensagem,
    String? parametroDisparo,
    bool? ativo,
    DateTime? criadoEm,
    DateTime? resolvidoEm,
    String? resolvidoPor,
  }) {
    return Alerta(
      id: id ?? this.id,
      talhaoId: talhaoId ?? this.talhaoId,
      propriedadeId: propriedadeId ?? this.propriedadeId,
      regra: regra ?? this.regra,
      severidade: severidade ?? this.severidade,
      titulo: titulo ?? this.titulo,
      mensagem: mensagem ?? this.mensagem,
      parametroDisparo: parametroDisparo ?? this.parametroDisparo,
      ativo: ativo ?? this.ativo,
      criadoEm: criadoEm ?? this.criadoEm,
      resolvidoEm: resolvidoEm ?? this.resolvidoEm,
      resolvidoPor: resolvidoPor ?? this.resolvidoPor,
    );
  }

  factory Alerta.fromMap(Map<String, dynamic> map) {
    return Alerta(
      id: map['id']?.toString() ?? '',
      talhaoId: map['talhao_id']?.toString() ?? '',
      propriedadeId: map['propriedade_id']?.toString() ?? '',
      regra: RegraAlerta.fromApiValue(map['regra']?.toString()),
      severidade: Severidade.fromApiValue(map['severidade']?.toString()),
      titulo: map['titulo']?.toString() ?? '',
      mensagem: map['mensagem']?.toString() ?? '',
      parametroDisparo: map['parametro_disparo']?.toString() ?? '',
      ativo: map['ativo'] as bool? ?? true,
      criadoEm: DateTime.tryParse(map['criado_em']?.toString() ?? '') ??
          DateTime.now(),
      resolvidoEm: DateTime.tryParse(map['resolvido_em']?.toString() ?? ''),
      resolvidoPor: map['resolvido_por']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'talhao_id': talhaoId,
      'propriedade_id': propriedadeId,
      'regra': regra.apiValue,
      'severidade': severidade.apiValue,
      'titulo': titulo,
      'mensagem': mensagem,
      'parametro_disparo': parametroDisparo,
      'ativo': ativo,
      'criado_em': criadoEm.toUtc().toIso8601String(),
      'resolvido_em': resolvidoEm?.toUtc().toIso8601String(),
      'resolvido_por': resolvidoPor,
    };
  }
}

