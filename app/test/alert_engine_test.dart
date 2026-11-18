import 'package:agro_campo/models/alerta.dart';
import 'package:agro_campo/models/registro_campo.dart';
import 'package:agro_campo/models/talhao.dart';
import 'package:agro_campo/models/usuario.dart';
import 'package:agro_campo/services/alert_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ref = DateTime(2026, 11, 17, 10, 0);

  Talhao buildTalhao({
    double umidade = 50.0,
    SituacaoTalhao situacao = SituacaoTalhao.saudavel,
    int diasParaColheita = 30,
  }) {
    return Talhao(
      id: 't-1',
      propriedadeId: 'p-1',
      identificacao: 'Talhão Norte',
      cultura: 'Soja',
      areaHa: 20,
      dataPlantio: ref.subtract(const Duration(days: 60)),
      previsaoColheita: ref.add(Duration(days: diasParaColheita)),
      umidade: umidade,
      situacao: situacao,
      observacoes: '',
      ultimaAtualizacao: ref,
      criadoPor: 'u-1',
    );
  }

  group('AlertEngine', () {
    test('gera alerta de umidade baixa quando umidade < 35%', () {
      final talhao = buildTalhao(umidade: 28.5);
      final result = AlertEngine.avaliar(
        talhao: talhao,
        alertasExistentes: const [],
        referencia: ref,
      );

      expect(result.novosAlertas.length, 1);
      expect(result.novosAlertas.first.regra, RegraAlerta.umidadeBaixa);
      expect(result.novosAlertas.first.talhaoId, 't-1');
    });

    test('resolve automaticamente alerta de umidade quando umidade >= 35%', () {
      final existente = Alerta(
        id: 'a-1',
        talhaoId: 't-1',
        propriedadeId: 'p-1',
        regra: RegraAlerta.umidadeBaixa,
        severidade: Severidade.media,
        titulo: 'Umidade baixa',
        mensagem: 'Teste',
        parametroDisparo: '28%',
        ativo: true,
        criadoEm: ref,
      );

      final result = AlertEngine.avaliar(
        talhao: buildTalhao(umidade: 45.0),
        alertasExistentes: [existente],
        referencia: ref,
      );

      expect(result.novosAlertas, isEmpty);
      expect(result.alertasResolvidosIds, contains('a-1'));
    });

    test('gera alerta ao registrar ocorrência de praga ou doença', () {
      final talhao = buildTalhao(umidade: 55.0);
      final ocorrencia = RegistroCampo(
        id: 'r-1',
        talhaoId: 't-1',
        propriedadeId: 'p-1',
        tipo: TipoRegistroCampo.ocorrencia,
        categoriaOcorrencia: CategoriaOcorrencia.praga,
        severidade: Severidade.alta,
        titulo: 'Foco de lagarta',
        descricao: 'Detectada na borda leste.',
        autorNome: 'Mariana',
        autorPerfil: UserRole.agronomo,
        criadoEm: ref,
      );

      final result = AlertEngine.avaliar(
        talhao: talhao,
        alertasExistentes: const [],
        novoRegistro: ocorrencia,
        referencia: ref,
      );

      expect(result.novosAlertas.length, 1);
      expect(
        result.novosAlertas.first.regra,
        RegraAlerta.ocorrenciaPragaDoenca,
      );
      expect(result.novosAlertas.first.severidade, Severidade.alta);
    });

    test('gera alerta de proximidade de colheita (<= 7 dias) e atraso (< 0)', () {
      final proximo = AlertEngine.avaliar(
        talhao: buildTalhao(diasParaColheita: 5),
        alertasExistentes: const [],
        referencia: ref,
      );
      expect(proximo.novosAlertas.length, 1);
      expect(
        proximo.novosAlertas.first.regra,
        RegraAlerta.proximidadeColheita,
      );

      final atrasado = AlertEngine.avaliar(
        talhao: buildTalhao(diasParaColheita: -2),
        alertasExistentes: const [],
        referencia: ref,
      );
      expect(atrasado.novosAlertas.length, 1);
      expect(atrasado.novosAlertas.first.regra, RegraAlerta.colheitaAtrasada);
    });
  });
}

