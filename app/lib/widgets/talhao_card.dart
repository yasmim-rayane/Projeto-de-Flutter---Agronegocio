import 'package:material_ui/material_ui.dart';

import '../models/alerta.dart';
import '../models/propriedade.dart';
import '../models/registro_campo.dart';
import '../models/talhao.dart';
import '../utils/formatters.dart';
import 'agro_theme.dart';
import 'status_badge.dart';

/// Card principal de um talhão respondendo rapidamente às cinco perguntas do edital.
class TalhaoCard extends StatelessWidget {
  const TalhaoCard({
    super.key,
    required this.talhao,
    required this.propriedade,
    required this.ocorrencias,
    required this.alertasAtivos,
    required this.onTap,
  });

  final Talhao talhao;
  final Propriedade? propriedade;
  final List<RegistroCampo> ocorrencias;
  final List<Alerta> alertasAtivos;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = AgroTheme.corSituacao(talhao.situacao);
    final diasColheita = talhao.diasParaColheita();
    final colheitaTexto = talhao.situacao == SituacaoTalhao.colhido
        ? 'Colhido (${AgroFormatters.formatDate(talhao.previsaoColheita)})'
        : diasColheita < 0
            ? '${AgroFormatters.formatDate(talhao.previsaoColheita)} (${diasColheita.abs()}d atraso)'
            : '${AgroFormatters.formatDate(talhao.previsaoColheita)} (em ${diasColheita}d)';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          talhao.identificacao,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          propriedade?.nome ?? 'Propriedade não vinculada',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(
                    label: talhao.situacao.label,
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.eco_outlined,
                      label: 'Cultura / Área',
                      value:
                          '${talhao.cultura} • ${talhao.areaHa.toStringAsFixed(1)} ha',
                    ),
                  ),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.water_drop_outlined,
                      label: 'Umidade do solo',
                      value: '${talhao.umidade.toStringAsFixed(1)}%',
                      highlightColor:
                          talhao.umidade < 35 ? Colors.red.shade700 : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.calendar_today_outlined,
                      label: 'Plantio',
                      value: AgroFormatters.formatDate(talhao.dataPlantio),
                    ),
                  ),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.event_available_outlined,
                      label: 'Previsão de colheita',
                      value: colheitaTexto,
                      highlightColor:
                          diasColheita <= 7 && talhao.situacao != SituacaoTalhao.colhido
                              ? Colors.orange.shade800
                              : null,
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),
              Row(
                children: [
                  Icon(
                    Icons.report_problem_outlined,
                    size: 16,
                    color: ocorrencias.isEmpty
                        ? Colors.grey.shade600
                        : Colors.orange.shade800,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ocorrencias.isEmpty
                          ? 'Sem ocorrências registradas'
                          : '${ocorrencias.length} ocorrência(s) • Última: ${ocorrencias.first.titulo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  if (alertasAtivos.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    StatusBadge(
                      label: '${alertasAtivos.length} alerta(s)',
                      color: Colors.red.shade700,
                      icon: Icons.notifications_active_outlined,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.highlightColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: highlightColor ?? Colors.grey.shade700),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: highlightColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
