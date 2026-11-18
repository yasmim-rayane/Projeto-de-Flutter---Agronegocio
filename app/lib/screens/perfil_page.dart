import 'package:material_ui/material_ui.dart';

import '../services/permission_service.dart';
import '../state/agro_controller.dart';
import '../widgets/status_badge.dart';

/// Tela de perfil exibindo usuário logado, modo de persistência e permissões.
class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key, required this.controller});

  final AgroController controller;

  @override
  Widget build(BuildContext context) {
    final user = controller.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil e Permissões'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(
                      Icons.person,
                      size: 38,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.nome,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 10),
                  StatusBadge(
                    label: user.perfil.label,
                    color: const Color(0xFF1B5E20),
                    icon: Icons.verified_user_outlined,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    controller.isRemoteMode
                        ? 'Persistência: Supabase Remoto (RLS ativo)'
                        : 'Persistência: Local em dispositivo (configure SUPABASE_URL para remoto)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Permissões do seu perfil',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...PermissionAction.values.map((action) {
                    final allowed = PermissionService.can(user.perfil, action);
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        allowed ? Icons.check_circle : Icons.block,
                        color: allowed ? Colors.green.shade700 : Colors.grey,
                      ),
                      title: Text(action.descricao),
                      subtitle: Text(
                        allowed ? 'Permitido' : 'Bloqueado para este perfil',
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: controller.logout,
            icon: const Icon(Icons.logout),
            label: const Text('Sair da conta'),
          ),
        ],
      ),
    );
  }
}
