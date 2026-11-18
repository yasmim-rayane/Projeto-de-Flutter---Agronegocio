import '../models/alerta.dart';
import '../models/registro_campo.dart';
import '../models/talhao.dart';
import 'id_generator.dart';

/// Resultado da avaliação automática das regras de negócio sobre um talhão.
class AlertEvaluationResult {
  const AlertEvaluationResult({
    required this.novosAlertas,
    required this.alertasResolvidosIds,
  });

  final List<Alerta> novosAlertas;
  final List<String> alertasResolvidosIds;
}

/// Motor determinístico de geração e atualização automática de alertas.
///
/// Regras implementadas com base nos exemplos do edital (p. 3):
/// 1. Umidade do solo abaixo de [umidadeLimiteMinimo] (35%).
/// 2. Ocorrência de praga ou doença registrada em campo.
/// 3. Proximidade da colheita ([diasProximidadeColheita] = 7 dias) ou atraso
///    para talhões ainda não colhidos.
class AlertEngine {
  static const double umidadeLimiteMinimo = 35.0;
  static const int diasProximidadeColheita = 7;

  /// Avalia o estado atual de [talhao] (e eventual [novoRegistro]) contra os
  /// [alertasExistentes] para evitar duplicidades e resolver pendências sanadas.
  static AlertEvaluationResult avaliar({
    required Talhao talhao,
    required List<Alerta> alertasExistentes,
    RegistroCampo? novoRegistro,
    DateTime? referencia,
  }) {
    final agora = referencia ?? DateTime.now();
    final ativosDoTalhao = alertasExistentes
        .where((a) => a.talhaoId == talhao.id && a.ativo)
        .toList();

    final novos = <Alerta>[];
    final resolvidosIds = <String>[];

    bool possuiAtivo(RegraAlerta regra) =>
        ativosDoTalhao.any((a) => a.regra == regra);

    void marcarResolvido(RegraAlerta regra) {
      for (final a in ativosDoTalhao.where((item) => item.regra == regra)) {
        resolvidosIds.add(a.id);
      }
    }

    // Regra 1: Umidade abaixo do limite mínimo (apenas para talhões não colhidos)
    if (talhao.situacao != SituacaoTalhao.colhido &&
        talhao.umidade < umidadeLimiteMinimo) {
      if (!possuiAtivo(RegraAlerta.umidadeBaixa)) {
        novos.add(
          Alerta(
            id: IdGenerator.uuidV4(),
            talhaoId: talhao.id,
            propriedadeId: talhao.propriedadeId,
            regra: RegraAlerta.umidadeBaixa,
            severidade:
                talhao.umidade < 25.0 ? Severidade.alta : Severidade.media,
            titulo: 'Umidade baixa em ${talhao.identificacao}',
            mensagem:
                'A cultura ${talhao.cultura} atingiu ${talhao.umidade.toStringAsFixed(1)}% de umidade, abaixo do mínimo operacional de ${umidadeLimiteMinimo.toStringAsFixed(0)}%. Avaliar irrigação.',
            parametroDisparo:
                'Umidade atual: ${talhao.umidade.toStringAsFixed(1)}% (< ${umidadeLimiteMinimo.toStringAsFixed(0)}%)',
            ativo: true,
            criadoEm: agora,
          ),
        );
      }
    } else {
      marcarResolvido(RegraAlerta.umidadeBaixa);
    }

    // Regra 2: Ocorrência de praga ou doença registrada no talhão
    if (novoRegistro != null &&
        novoRegistro.tipo == TipoRegistroCampo.ocorrencia &&
        (novoRegistro.categoriaOcorrencia == CategoriaOcorrencia.praga ||
            novoRegistro.categoriaOcorrencia == CategoriaOcorrencia.doenca)) {
      final categoria = novoRegistro.categoriaOcorrencia!.label;
      final severidadeOcorrencia = novoRegistro.severidade ?? Severidade.media;
      novos.add(
        Alerta(
          id: IdGenerator.uuidV4(),
          talhaoId: talhao.id,
          propriedadeId: talhao.propriedadeId,
          regra: RegraAlerta.ocorrenciaPragaDoenca,
          severidade: severidadeOcorrencia,
          titulo: '$categoria detectada em ${talhao.identificacao}',
          mensagem:
              '${novoRegistro.titulo}: ${novoRegistro.descricao.isEmpty ? "Requer vistoria agronômica." : novoRegistro.descricao}',
          parametroDisparo:
              'Ocorrência: $categoria | Severidade: ${severidadeOcorrencia.label}',
          ativo: true,
          criadoEm: agora,
        ),
      );
    }

    // Regra 3: Proximidade ou atraso na previsão de colheita
    if (talhao.situacao == SituacaoTalhao.colhido) {
      marcarResolvido(RegraAlerta.proximidadeColheita);
      marcarResolvido(RegraAlerta.colheitaAtrasada);
    } else {
      final dias = talhao.diasParaColheita(agora);
      if (dias < 0) {
        marcarResolvido(RegraAlerta.proximidadeColheita);
        if (!possuiAtivo(RegraAlerta.colheitaAtrasada)) {
          final atraso = dias.abs();
          novos.add(
            Alerta(
              id: IdGenerator.uuidV4(),
              talhaoId: talhao.id,
              propriedadeId: talhao.propriedadeId,
              regra: RegraAlerta.colheitaAtrasada,
              severidade: Severidade.alta,
              titulo: 'Colheita em atraso: ${talhao.identificacao}',
              mensagem:
                  'A previsão de colheita de ${talhao.cultura} venceu há $atraso dia(s) e o talhão ainda não foi marcado como colhido.',
              parametroDisparo: 'Atraso de $atraso dia(s) sobre a previsão',
              ativo: true,
              criadoEm: agora,
            ),
          );
        }
      } else if (dias <= diasProximidadeColheita) {
        marcarResolvido(RegraAlerta.colheitaAtrasada);
        if (!possuiAtivo(RegraAlerta.proximidadeColheita)) {
          novos.add(
            Alerta(
              id: IdGenerator.uuidV4(),
              talhaoId: talhao.id,
              propriedadeId: talhao.propriedadeId,
              regra: RegraAlerta.proximidadeColheita,
              severidade: dias <= 2 ? Severidade.alta : Severidade.media,
              titulo: 'Colheita próxima em ${talhao.identificacao}',
              mensagem: dias == 0
                  ? 'A colheita de ${talhao.cultura} está prevista para hoje.'
                  : 'Faltam $dias dia(s) para a colheita prevista de ${talhao.cultura}.',
              parametroDisparo:
                  'Prazo restante: $dias dia(s) (janela <= $diasProximidadeColheita dias)',
              ativo: true,
              criadoEm: agora,
            ),
          );
        }
      } else {
        marcarResolvido(RegraAlerta.proximidadeColheita);
        marcarResolvido(RegraAlerta.colheitaAtrasada);
      }
    }

    return AlertEvaluationResult(
      novosAlertas: novos,
      alertasResolvidosIds: resolvidosIds,
    );
  }
}

