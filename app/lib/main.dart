import 'package:material_ui/material_ui.dart';

import 'screens/login_page.dart';
import 'screens/main_shell_page.dart';
import 'services/agro_repository.dart';
import 'services/weather_api_service.dart';
import 'state/agro_controller.dart';
import 'widgets/agro_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AgroController(
    repository: createDefaultRepository(),
    weatherService: WeatherApiService(),
  )..init();

  runApp(AgroCampoApp(controller: controller));
}

/// Widget raiz da aplicação AgroCampo.
class AgroCampoApp extends StatelessWidget {
  const AgroCampoApp({super.key, required this.controller});

  final AgroController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgroCampo MVP',
      debugShowCheckedModeBanner: false,
      theme: AgroTheme.buildTheme(),
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.isInitializing) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Carregando dados agrícolas...'),
                  ],
                ),
              ),
            );
          }

          if (controller.currentUser == null) {
            return LoginPage(controller: controller);
          }

          return MainShellPage(controller: controller);
        },
      ),
    );
  }
}
