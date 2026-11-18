import '../utils/formatters.dart';

/// Situação operacional atual de um talhão em campo.
enum SituacaoTalhao {
  saudavel('saudavel', 'Saudável'),
  atencao('atencao', 'Em Atenção'),
  critico('critico', 'Crítico'),
  colhido('colhido', 'Colhido');

  const SituacaoTalhao(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static SituacaoTalhao fromApiValue(String? value) {
    return SituacaoTalhao.values.firstWhere(
      (s) => s.apiValue == value,
      orElse: () => SituacaoTalhao.saudavel,
    );
  }
}

/// Representa um talhão agrícola vinculado a uma propriedade.
class Talhao {
  const Talhao({
    required this.id,
    required this.propriedadeId,
    required this.identificacao,
    required this.cultura,
    required this.areaHa,
    required this.dataPlantio,
    required this.previsaoColheita,
    required this.umidade,
    required this.situacao,
    required this.observacoes,
    required this.ultimaAtualizacao,
    required this.criadoPor,
  });

  final String id;
  final String propriedadeId;
  final String identificacao;
  final String cultura;
  final double areaHa;
  final DateTime dataPlantio;
  final DateTime previsaoColheita;
  final double umidade;
  final SituacaoTalhao situacao;
  final String observacoes;
  final DateTime ultimaAtualizacao;
  final String criadoPor;

  /// Dias restantes até a previsão de colheita (negativo indica atraso).
  int diasParaColheita([DateTime? referencia]) {
    final base = referencia ?? DateTime.now();
    final hoje = DateTime(base.year, base.month, base.day);
    final alvo = DateTime(
      previsaoColheita.year,
      previsaoColheita.month,
      previsaoColheita.day,
    );
    return alvo.difference(hoje).inDays;
  }

  Talhao copyWith({
    String? id,
    String? propriedadeId,
    String? identificacao,
    String? cultura,
    double? areaHa,
    DateTime? dataPlantio,
    DateTime? previsaoColheita,
    double? umidade,
    SituacaoTalhao? situacao,
    String? observacoes,
    DateTime? ultimaAtualizacao,
    String? criadoPor,
  }) {
    return Talhao(
      id: id ?? this.id,
      propriedadeId: propriedadeId ?? this.propriedadeId,
      identificacao: identificacao ?? this.identificacao,
      cultura: cultura ?? this.cultura,
      areaHa: areaHa ?? this.areaHa,
      dataPlantio: dataPlantio ?? this.dataPlantio,
      previsaoColheita: previsaoColheita ?? this.previsaoColheita,
      umidade: umidade ?? this.umidade,
      situacao: situacao ?? this.situacao,
      observacoes: observacoes ?? this.observacoes,
      ultimaAtualizacao: ultimaAtualizacao ?? this.ultimaAtualizacao,
      criadoPor: criadoPor ?? this.criadoPor,
    );
  }

  factory Talhao.fromMap(Map<String, dynamic> map) {
    return Talhao(
      id: map['id']?.toString() ?? '',
      propriedadeId: map['propriedade_id']?.toString() ?? '',
      identificacao: map['identificacao']?.toString() ?? '',
      cultura: map['cultura']?.toString() ?? '',
      areaHa: (map['area_ha'] as num?)?.toDouble() ?? 0.0,
      dataPlantio: DateTime.tryParse(map['data_plantio']?.toString() ?? '') ??
          DateTime.now(),
      previsaoColheita:
          DateTime.tryParse(map['previsao_colheita']?.toString() ?? '') ??
              DateTime.now(),
      umidade: (map['umidade'] as num?)?.toDouble() ?? 0.0,
      situacao: SituacaoTalhao.fromApiValue(map['situacao']?.toString()),
      observacoes: map['observacoes']?.toString() ?? '',
      ultimaAtualizacao:
          DateTime.tryParse(map['ultima_atualizacao']?.toString() ?? '') ??
              DateTime.now(),
      criadoPor: map['criado_por']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'propriedade_id': propriedadeId,
      'identificacao': identificacao,
      'cultura': cultura,
      'area_ha': areaHa,
      'data_plantio': AgroFormatters.toIsoDate(dataPlantio),
      'previsao_colheita': AgroFormatters.toIsoDate(previsaoColheita),
      'umidade': umidade,
      'situacao': situacao.apiValue,
      'observacoes': observacoes,
      'ultima_atualizacao': ultimaAtualizacao.toUtc().toIso8601String(),
      'criado_por': criadoPor.isEmpty ? null : criadoPor,
    };
  }
}

