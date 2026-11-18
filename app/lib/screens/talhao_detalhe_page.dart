import 'package:material_ui/material_ui.dart';

import '../models/registro_campo.dart';
import '../models/talhao.dart';
import '../services/permission_service.dart';
import '../state/agro_controller.dart';
import '../utils/formatters.dart';
import '../widgets/agro_theme.dart';
import '../widgets/alerta_card.dart';
import '../widgets/clima_card.dart';
import '../widgets/status_badge.dart';
import 'registro_campo_page.dart';
import 'talhao_form_page.dart';

/// Tela de detalhes do talhão: visão completa, clima Open-Meteo, ações e histórico.
class TalhaoDetalhePage extends StatefulWidget {
  const TalhaoDetalhePage({
    super.key,
    required this.controller,
    required this.talhaoId,
  });

  final AgroController controller;
  final String talhaoId;

  @override
  State<TalhaoDetalhePage> createState() => _TalhaoDetalhePageState();
}

class _TalhaoDetalhePageState extends State<TalhaoDetalhePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final talhao = widget.controller.talhaoPorId(widget.talhaoId);
      if (talhao != null) {
        final prop = widget.controller.propriedadePorId(talhao.propriedadeId);
        if (prop != null) {
          widget.controller.carregarClimaPropriedade(prop);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final talhao = ctrl.talhaoPorId(widget.talhaoId);

        if (talhao == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalhes do Talhão')),
            body: const Center(
              child: Text('Talhão não encontrado.'),
            ),
          );
        }

        final prop = ctrl.propriedadePorId(talhao.propriedadeId);
        final historico = ctrl.registrosDoTalhao(talhao.id);
        final alertasAtivos = ctrl.alertasAtivosDoTalhao(talhao.id);

        final podeEditarPlantio = ctrl.can(PermissionAction.editarPlantioTalhao);
        final podeAtualizarCondicao =
            ctrl.can(PermissionAction.atualizarCondicaoTalhao);
        final podeRegistrarOcorrencia =
            ctrl.can(PermissionAction.registrarOcorrencia);
        final podeResolverAlerta = ctrl.can(PermissionAction.resolverAlerta);

        final diasColheita = talhao.diasParaColheita();
        final colheitaResumo = talhao.situacao == SituacaoTalhao.colhido
            ? 'Colhido'
            : diasColheita < 0
                ? 'Atrasada em ${diasColheita.abs()} dia(s)'
                : diasColheita == 0
                    ? 'Prevista para hoje'
                    : 'Em $diasColheita dia(s)';

        return Scaffold(
          appBar: AppBar(
            title: Text(talhao.identificacao),
            actions: [
              if (podeEditarPlantio)
                IconButton(
                  tooltip: 'Editar plantio e talhão',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TalhaoFormPage(
                          controller: ctrl,
                          talhao: talhao,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              prop?.nome ?? 'Propriedade não informada',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          StatusBadge(
                            label: talhao.situacao.label,
                            color: AgroTheme.corSituacao(talhao.situacao),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _DetalheLinha(
                        titulo: 'O que está plantado',
                        valor:
                            '${talhao.cultura} (${talhao.areaHa.toStringAsFixed(1)} ha)',
                      ),
                      _DetalheLinha(
                        titulo: 'Data do plantio',
                        valor: AgroFormatters.formatDate(talhao.dataPlantio),
                      ),
                      _DetalheLinha(
                        titulo: 'Previsão de colheita',
                        valor:
                            '${AgroFormatters.formatDate(talhao.previsaoColheita)} • $colheitaResumo',
                      ),
                      _DetalheLinha(
                        titulo: 'Umidade atual do solo',
                        valor: '${talhao.umidade.toStringAsFixed(1)}%',
                      ),
                      _DetalheLinha(
                        titulo: 'Última atualização',
                        valor: AgroFormatters.formatDateTime(
                          talhao.ultimaAtualizacao,
                        ),
                      ),
                      if (talhao.observacoes.isNotEmpty) ...[
                        const Divider(height: 18),
                        const Text(
                          'Observações',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(talhao.observacoes),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (podeAtualizarCondicao)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RegistroCampoPage(
                                controller: ctrl,
                                talhao: talhao,
                                modo: RegistroModo.condicao,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.water_drop_outlined, size: 18),
                        label: const Text('Atualizar Condição'),
                      ),
                    ),
                  if (podeAtualizarCondicao && podeRegistrarOcorrencia)
                    const SizedBox(width: 8),
                  if (podeRegistrarOcorrencia)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          foregroundColor: Colors.orange.shade900,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RegistroCampoPage(
                                controller: ctrl,
                                talhao: talhao,
                                modo: RegistroModo.ocorrencia,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.bug_report_outlined, size: 18),
                        label: const Text('Ocorrência'),
                      ),
                    ),
                ],
              ),
              if (prop != null) ...[
                const SizedBox(height: 12),
                ClimaCard(
                  propriedade: prop,
                  clima: ctrl.climaDaPropriedade(prop.id),
                  carregando: ctrl.carregandoClimaDaPropriedade(prop.id),
                  erro: ctrl.erroClimaDaPropriedade(prop.id),
                  onAtualizar: () =>
                      ctrl.carregarClimaPropriedade(prop, force: true),
                ),
              ],
              if (alertasAtivos.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Alertas Ativos do Talhão (${alertasAtivos.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...alertasAtivos.map(
                  (alerta) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AlertaCard(
                      alerta: alerta,
                      talhao: talhao,
                      propriedade: prop,
                      podeResolver: podeResolverAlerta,
                      onAbrirTalhao: null,
                      onResolver: () async {
                        try {
                          await ctrl.resolverAlerta(alerta.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Alerta marcado como resolvido.'),
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
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Histórico de Campo (${historico.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (historico.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhuma atividade registrada ainda.'),
                  ),
                )
              else
                ...historico.map((reg) => _HistoricoItemCard(registro: reg)),
            ],
          ),
        );
      },
    );
  }
}

class _DetalheLinha extends StatelessWidget {
  const _DetalheLinha({required this.titulo, required this.valor});

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              titulo,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoricoItemCard extends StatelessWidget {
  const _HistoricoItemCard({required this.registro});

  final RegistroCampo registro;

  @override
  Widget build(BuildContext context) {
    final (icone, cor) = switch (registro.tipo) {
      TipoRegistroCampo.plantio => (Icons.spa_outlined, const Color(0xFF1B5E20)),
      TipoRegistroCampo.condicao => (
          Icons.water_drop_outlined,
          const Color(0xFF1565C0)
        ),
      TipoRegistroCampo.ocorrencia => (
          Icons.report_problem_outlined,
          Colors.orange.shade800
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: cor.withValues(alpha: 0.12),
                child: Icon(icone, size: 18, color: cor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            registro.titulo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          registro.tipo.label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: cor,
                          ),
                        ),
                      ],
                    ),
                    if (registro.categoriaOcorrencia != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Categoria: ${registro.categoriaOcorrencia!.label}'
                        '${registro.severidade != null ? ' • Severidade: ${registro.severidade!.label}' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (registro.descricao.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        registro.descricao,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${registro.autorNome} (${registro.autorPerfil.label}) • ${AgroFormatters.formatDateTime(registro.criadoEm)}'
                      '${registro.umidadeRegistrada != null ? ' • Umid.: ${registro.umidadeRegistrada!.toStringAsFixed(0)}%' : ''}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
