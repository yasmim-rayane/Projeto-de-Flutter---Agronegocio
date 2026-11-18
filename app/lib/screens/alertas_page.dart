import 'package:material_ui/material_ui.dart';

import '../services/permission_service.dart';
import '../state/agro_controller.dart';
import '../widgets/alerta_card.dart';
import 'talhao_detalhe_page.dart';

enum _FiltroAlerta { ativos, resolvidos, todos }

/// Central de alertas gerados automaticamente pelas regras de negócio do MVP.
class AlertasPage extends StatefulWidget {
  const AlertasPage({super.key, required this.controller});

  final AgroController controller;

  @override
  State<AlertasPage> createState() => _AlertasPageState();
}

class _AlertasPageState extends State<AlertasPage> {
  _FiltroAlerta _filtro = _FiltroAlerta.ativos;

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final podeResolver = ctrl.can(PermissionAction.resolverAlerta);

    final lista = switch (_filtro) {
      _FiltroAlerta.ativos => ctrl.alertasAtivos,
      _FiltroAlerta.resolvidos => ctrl.alertasResolvidos,
      _FiltroAlerta.todos => ctrl.alertas,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas Automáticos'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: ctrl.refreshData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: ctrl.refreshData,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Card(
              color: const Color(0xFFFFF8E1),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Regras automáticas ativas: (1) Umidade < 35% • (2) Ocorrência de praga/doença • (3) Colheita em até 7 dias ou em atraso.',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<_FiltroAlerta>(
              segments: [
                ButtonSegment(
                  value: _FiltroAlerta.ativos,
                  label: Text('Ativos (${ctrl.alertasAtivos.length})'),
                ),
                ButtonSegment(
                  value: _FiltroAlerta.resolvidos,
                  label: Text('Resolvidos (${ctrl.alertasResolvidos.length})'),
                ),
                ButtonSegment(
                  value: _FiltroAlerta.todos,
                  label: Text('Todos (${ctrl.alertas.length})'),
                ),
              ],
              selected: {_filtro},
              onSelectionChanged: (sel) {
                setState(() => _filtro = sel.first);
              },
            ),
            const SizedBox(height: 12),
            if (lista.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 42,
                        color: Color(0xFF2E7D32),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Nenhum alerta neste filtro.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...lista.map(
                (alerta) {
                  final talhao = ctrl.talhaoPorId(alerta.talhaoId);
                  final prop = ctrl.propriedadePorId(alerta.propriedadeId);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AlertaCard(
                      alerta: alerta,
                      talhao: talhao,
                      propriedade: prop,
                      podeResolver: podeResolver,
                      onAbrirTalhao: talhao == null
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TalhaoDetalhePage(
                                    controller: ctrl,
                                    talhaoId: talhao.id,
                                  ),
                                ),
                              );
                            },
                      onResolver: () async {
                        try {
                          await ctrl.resolverAlerta(alerta.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Alerta resolvido com sucesso!'),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
