import 'talhao.dart';
import 'usuario.dart';

/// Tipo de evento registrado no histórico de campo de um talhão.
enum TipoRegistroCampo {
  plantio('plantio', 'Plantio'),
  condicao('condicao', 'Condição Atual'),
  ocorrencia('ocorrencia', 'Ocorrência');

  const TipoRegistroCampo(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static TipoRegistroCampo fromApiValue(String? value) {
    return TipoRegistroCampo.values.firstWhere(
      (t) => t.apiValue == value,
      orElse: () => TipoRegistroCampo.condicao,
    );
  }
}

/// Categorias possíveis para ocorrências agrícolas registradas em campo.
enum CategoriaOcorrencia {
  praga('praga', 'Praga'),
  doenca('doenca', 'Doença'),
  deficienciaHidrica('deficiencia_hidrica', 'Déficit Hídrico'),
  clima('clima', 'Evento Climático'),
  manutencao('manutencao', 'Manejo / Manutenção'),
  outro('outro', 'Outra Ocorrência');

  const CategoriaOcorrencia(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static CategoriaOcorrencia? fromApiValue(String? value) {
    if (value == null || value.isEmpty) return null;
    return CategoriaOcorrencia.values.firstWhere(
      (c) => c.apiValue == value,
      orElse: () => CategoriaOcorrencia.outro,
    );
  }
}

/// Nível de severidade compartilhado entre ocorrências e alertas.
enum Severidade {
  baixa('baixa', 'Baixa'),
  media('media', 'Média'),
  alta('alta', 'Alta');

  const Severidade(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static Severidade fromApiValue(String? value) {
    return Severidade.values.firstWhere(
      (s) => s.apiValue == value,
      orElse: () => Severidade.media,
    );
  }
}

/// Item cronológico no histórico de atividades de um talhão.
class RegistroCampo {
  const RegistroCampo({
    required this.id,
    required this.talhaoId,
    required this.propriedadeId,
    required this.tipo,
    this.categoriaOcorrencia,
    this.severidade,
    required this.titulo,
    required this.descricao,
    this.umidadeRegistrada,
    this.situacaoRegistrada,
    required this.autorNome,
    required this.autorPerfil,
    required this.criadoEm,
  });

  final String id;
  final String talhaoId;
  final String propriedadeId;
  final TipoRegistroCampo tipo;
  final CategoriaOcorrencia? categoriaOcorrencia;
  final Severidade? severidade;
  final String titulo;
  final String descricao;
  final double? umidadeRegistrada;
  final SituacaoTalhao? situacaoRegistrada;
  final String autorNome;
  final UserRole autorPerfil;
  final DateTime criadoEm;

  factory RegistroCampo.fromMap(Map<String, dynamic> map) {
    final situacaoRaw = map['situacao_registrada']?.toString();
    final severidadeRaw = map['severidade']?.toString();

    return RegistroCampo(
      id: map['id']?.toString() ?? '',
      talhaoId: map['talhao_id']?.toString() ?? '',
      propriedadeId: map['propriedade_id']?.toString() ?? '',
      tipo: TipoRegistroCampo.fromApiValue(map['tipo']?.toString()),
      categoriaOcorrencia: CategoriaOcorrencia.fromApiValue(
        map['categoria_ocorrencia']?.toString(),
      ),
      severidade:
          severidadeRaw == null ? null : Severidade.fromApiValue(severidadeRaw),
      titulo: map['titulo']?.toString() ?? '',
      descricao: map['descricao']?.toString() ?? '',
      umidadeRegistrada: (map['umidade_registrada'] as num?)?.toDouble(),
      situacaoRegistrada: situacaoRaw == null
          ? null
          : SituacaoTalhao.fromApiValue(situacaoRaw),
      autorNome: map['autor_nome']?.toString() ?? 'Equipe de Campo',
      autorPerfil: UserRole.fromApiValue(map['autor_perfil']?.toString()),
      criadoEm: DateTime.tryParse(map['criado_em']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap({String? autorId}) {
    return {
      'id': id,
      'talhao_id': talhaoId,
      'propriedade_id': propriedadeId,
      'tipo': tipo.apiValue,
      'categoria_ocorrencia': categoriaOcorrencia?.apiValue,
      'severidade': severidade?.apiValue,
      'titulo': titulo,
      'descricao': descricao,
      'umidade_registrada': umidadeRegistrada,
      'situacao_registrada': situacaoRegistrada?.apiValue,
      if (autorId != null && autorId.isNotEmpty) 'autor_id': autorId,
      'autor_nome': autorNome,
      'autor_perfil': autorPerfil.apiValue,
      'criado_em': criadoEm.toUtc().toIso8601String(),
    };
  }
}

