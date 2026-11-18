import 'package:agro_campo/main.dart';
import 'package:agro_campo/services/agro_repository.dart';
import 'package:agro_campo/services/weather_api_service.dart';
import 'package:agro_campo/state/agro_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  MockClient buildWeatherMock() {
    return MockClient((_) async {
      return http.Response(
        '''
        {
          "current": {
            "temperature_2m": 25.0,
            "relative_humidity_2m": 58,
            "precipitation": 0.0,
            "weather_code": 0,
            "wind_speed_10m": 8.0
          }
        }
        ''',
        200,
      );
    });
  }

  testWidgets(
      'Valida login, entra como Técnico Agrícola, filtra talhões e respeita permissões na UI',
      (tester) async {
    final controller = AgroController(
      repository: LocalAgroRepository(),
      weatherService: WeatherApiService(client: buildWeatherMock()),
    );
    await controller.init();

    await tester.pumpWidget(AgroCampoApp(controller: controller));
    await tester.pumpAndSettle();

    // Tenta submeter vazio para verificar validação
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe o e-mail.'), findsOneWidget);
    expect(find.text('Informe a senha.'), findsOneWidget);

    // Usa preenchimento rápido do perfil Técnico Agrícola
    await tester.ensureVisible(find.text('Técnico'));
    await tester.tap(find.text('Técnico'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    // Entrou na tela principal de talhões
    expect(find.text('Acompanhamento de Talhões'), findsOneWidget);
    final listScrollable = find
        .descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Talhão B2 - Várzea'),
      150,
      scrollable: listScrollable,
    );
    expect(find.text('Talhão B2 - Várzea'), findsOneWidget);

    // Técnico Agrícola não pode cadastrar novo talhão -> FAB oculto
    expect(find.text('Novo Talhão'), findsNothing);

    // Volta para o topo e testa filtro por texto
    await tester.scrollUntilVisible(
      find.byType(TextField).first,
      -200,
      scrollable: listScrollable,
    );
    await tester.enterText(
      find.byType(TextField).first,
      'Soja',
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Talhão A1 - Norte'),
      150,
      scrollable: listScrollable,
    );
    expect(find.text('Talhão A1 - Norte'), findsOneWidget);
    expect(find.text('Talhão B2 - Várzea'), findsNothing);

    // Limpa filtro e navega para detalhes do Talhão B2
    await tester.scrollUntilVisible(
      find.text('Limpar'),
      -150,
      scrollable: listScrollable,
    );
    await tester.tap(find.text('Limpar'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Talhão B2 - Várzea'),
      150,
      scrollable: listScrollable,
    );
    await tester.tap(find.text('Talhão B2 - Várzea'));
    await tester.pumpAndSettle();

    expect(find.text('Clima Atual da Propriedade (Open-Meteo)'), findsOneWidget);
    expect(find.text('25.0 °C'), findsOneWidget);
    expect(find.text('Atualizar Condição'), findsOneWidget);
  });

  testWidgets('Gestor da Propriedade visualiza botão de novo talhão e alertas',
      (tester) async {
    final controller = AgroController(
      repository: LocalAgroRepository(),
      weatherService: WeatherApiService(client: buildWeatherMock()),
    );
    await controller.init();

    await tester.pumpWidget(AgroCampoApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Gestor'));
    await tester.tap(find.text('Gestor'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Novo Talhão'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Alertas'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alertas Automáticos'), findsOneWidget);
    expect(find.text('Resolver alerta'), findsWidgets);
  });
}
