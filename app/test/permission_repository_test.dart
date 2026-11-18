import 'package:agro_campo/models/propriedade.dart';
import 'package:agro_campo/models/registro_campo.dart';
import 'package:agro_campo/models/talhao.dart';
import 'package:agro_campo/models/usuario.dart';
import 'package:agro_campo/services/agro_repository.dart';
import 'package:agro_campo/services/permission_service.dart';
import 'package:agro_campo/services/weather_api_service.dart';
import 'package:agro_campo/state/agro_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Permissões e fluxo completo de negócio', () {
    test('bloqueia operações não permitidas na camada de dados', () async {
      final repo = LocalAgroRepository();
      final tecnico = await repo.login(
        email: 'tecnico@agrocampo.app',
        senha: '123456',
      );
      expect(tecnico.perfil, UserRole.tecnicoAgricola);

      final propriedade = Propriedade(
        id: 'p-teste',
        nome: 'Fazenda Teste',
        municipio: 'Londrina',
        estado: 'PR',
        areaTotalHa: 100,
        latitude: -23.3,
        longitude: -51.1,
        criadoPor: tecnico.id,
        criadoEm: DateTime.now(),
      );

      await expectLater(
        () => repo.savePropriedade(
          user: tecnico,
          propriedade: propriedade,
          isUpdate: false,
        ),
        throwsA(isA<PermissionDeniedException>()),
      );

      final talhao = Talhao(
        id: 't-teste',
        propriedadeId: '22222222-2222-4222-8222-222222222222',
        identificacao: 'Talhão Z',
        cultura: 'Soja',
        areaHa: 10,
        dataPlantio: DateTime.now(),
        previsaoColheita: DateTime.now().add(const Duration(days: 90)),
        umidade: 50,
        situacao: SituacaoTalhao.saudavel,
        observacoes: '',
        ultimaAtualizacao: DateTime.now(),
        criadoPor: tecnico.id,
      );

      await expectLater(
        () => repo.saveTalhao(user: tecnico, talhao: talhao, isUpdate: false),
        throwsA(isA<PermissionDeniedException>()),
      );

      await expectLater(
        () => repo.resolverAlerta(
          user: tecnico,
          alertaId: '55555555-5555-4555-8555-555555555551',
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('executa fluxo completo ponta a ponta e persiste após reabrir', () async {
      final mockClient = MockClient(
        (_) async => http.Response('{"current":{}}', 200),
      );
      final controller = AgroController(
        repository: LocalAgroRepository(),
        weatherService: WeatherApiService(client: mockClient),
      );

      await controller.init();
      await controller.register(
        nome: 'João Gestor',
        email: 'joao.gestor@teste.com',
        senha: 'segredo123',
        perfil: UserRole.gestorPropriedade,
      );

      // 1. Cadastrar propriedade
      await controller.salvarPropriedade(
        nome: 'Sítio Primavera',
        municipio: 'Campinas',
        estado: 'SP',
        areaTotalHa: 80,
        latitude: -22.9056,
        longitude: -47.0608,
      );
      final prop = controller.propriedades
          .firstWhere((p) => p.nome == 'Sítio Primavera');

      // 2. Cadastrar talhão e informar cultura/plantio
      final plantio = DateTime.now().subtract(const Duration(days: 15));
      final colheita = DateTime.now().add(const Duration(days: 80));
      await controller.salvarTalhao(
        propriedadeId: prop.id,
        identificacao: 'Talhão C1 - Baixada',
        cultura: 'Café',
        areaHa: 18,
        dataPlantio: plantio,
        previsaoColheita: colheita,
        umidade: 48,
        situacao: SituacaoTalhao.saudavel,
        observacoes: 'Plantio inicial concluído.',
      );
      final talhao = controller.talhoes
          .firstWhere((t) => t.identificacao == 'Talhão C1 - Baixada');

      // 3. Atualizar condição com umidade abaixo do limite -> deve gerar alerta
      await controller.registrarCondicao(
        talhao: talhao,
        umidade: 26,
        situacao: SituacaoTalhao.atencao,
        observacoes: 'Solo seco após 6 dias sem chuva.',
      );

      // 4. Registrar ocorrência de praga -> deve gerar alerta adicional
      await controller.registrarOcorrencia(
        talhao: controller.talhaoPorId(talhao.id)!,
        categoria: CategoriaOcorrencia.praga,
        severidade: Severidade.alta,
        titulo: 'Broca-do-café',
        descricao: 'Incidência observada em 12% dos pés amostrados.',
      );

      // 5. Consultar histórico e alertas do talhão
      final historico = controller.registrosDoTalhao(talhao.id);
      expect(historico.length, 3); // plantio + condição + ocorrência

      final alertas = controller.alertasAtivosDoTalhao(talhao.id);
      expect(alertas.length, 2);

      // 6. Simular reabertura do aplicativo mantendo persistência
      final reopenedController = AgroController(
        repository: LocalAgroRepository(),
        weatherService: WeatherApiService(client: mockClient),
      );
      await reopenedController.init();

      expect(reopenedController.currentUser?.email, 'joao.gestor@teste.com');
      expect(
        reopenedController.talhoes.any((t) => t.id == talhao.id),
        isTrue,
      );
      expect(
        reopenedController.alertasAtivosDoTalhao(talhao.id).length,
        2,
      );
    });
  });
}

