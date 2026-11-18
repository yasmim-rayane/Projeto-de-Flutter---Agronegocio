import 'package:material_ui/material_ui.dart';

import '../models/alerta.dart';
import '../models/propriedade.dart';
import '../models/talhao.dart';
import '../utils/formatters.dart';
import 'agro_theme.dart';
import 'status_badge.dart';

/// Card de alerta operacional vinculado ao talhão e à regra disparada.
class AlertaCard extends StatelessWidget {
  const AlertaCard({
    super.key,
    required this.alerta,
    required this.talhao,
    required this.propriedade,
    required this.podeResolver,
    required this.onAbrirTalhao,
    required this.onResolver,
  });

  final Alerta alerta;
  final Talhao? talhao;
  final Propriedade? propriedade;
  final bool podeResolver;
  final VoidCallback? onAbrirTalhao;
  final VoidCallback? onResolver;

  @override
  Widget build(BuildContext context) {
    final color = alerta.ativo
        ? AgroTheme.corSeveridade(alerta.severidade)
        : Colors.grey.shade600;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  alerta.ativo
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alerta.titulo,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${talhao?.identificacao ?? 'Talhão'} • ${propriedade?.nome ?? 'Propriedade'}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: alerta.ativo
                      ? 'Severidade ${alerta.severidade.label}'
                      : 'Resolvido',
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              alerta.mensagem,
              style: const TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Regra: ${alerta.regra.label}\nGatilho: ${alerta.parametroDisparo}\nEmitido em: ${AgroFormatters.formatDateTime(alerta.criadoEm)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
              ),
            ),
            if (!alerta.ativo && alerta.resolvidoPor != null) ...[
              const SizedBox(height: 6),
              Text(
                'Resolvido por ${alerta.resolvidoPor} em ${alerta.resolvidoEm != null ? AgroFormatters.formatDateTime(alerta.resolvidoEm!) : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (onAbrirTalhao != null)
                  OutlinedButton.icon(
                    onPressed: onAbrirTalhao,
                    icon: const Icon(Icons.grass, size: 18),
                    label: const Text('Ver talhão'),
                  ),
                const Spacer(),
                if (alerta.ativo && podeResolver && onResolver != null)
                  FilledButton.icon(
                    onPressed: onResolver,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Resolver alerta'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
