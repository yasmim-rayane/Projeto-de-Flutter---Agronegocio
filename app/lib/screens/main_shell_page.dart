import 'package:material_ui/material_ui.dart';

import '../state/agro_controller.dart';
import 'alertas_page.dart';
import 'perfil_page.dart';
import 'propriedades_page.dart';
import 'talhoes_list_page.dart';

/// Estrutura principal pós-login com navegação por abas e contador de alertas.
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key, required this.controller});

  final AgroController controller;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final activeAlerts = widget.controller.alertasAtivos.length;

        final pages = [
          TalhoesListPage(controller: widget.controller),
          AlertasPage(controller: widget.controller),
          PropriedadesPage(controller: widget.controller),
          PerfilPage(controller: widget.controller),
        ];

        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.grass_outlined),
                selectedIcon: Icon(Icons.grass),
                label: 'Talhões',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: activeAlerts > 0,
                  label: Text('$activeAlerts'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: activeAlerts > 0,
                  label: Text('$activeAlerts'),
                  child: const Icon(Icons.notifications_active),
                ),
                label: 'Alertas',
              ),
              const NavigationDestination(
                icon: Icon(Icons.landscape_outlined),
                selectedIcon: Icon(Icons.landscape),
                label: 'Propriedades',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ],
          ),
        );
      },
    );
  }
}
