import 'package:material_ui/material_ui.dart';

import '../models/clima_info.dart';
import '../models/propriedade.dart';
import '../utils/formatters.dart';

/// Card que apresenta dados reais de clima consultados na API Open-Meteo.
class ClimaCard extends StatelessWidget {
  const ClimaCard({
    super.key,
    required this.propriedade,
    required this.clima,
    required this.carregando,
    required this.erro,
    required this.onAtualizar,
  });

  final Propriedade propriedade;
  final ClimaInfo? clima;
  final bool carregando;
  final String? erro;
  final VoidCallback onAtualizar;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wb_sunny_outlined, color: Color(0xFF1B5E20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Clima Atual da Propriedade (Open-Meteo)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${propriedade.localizacao} • ${propriedade.latitude.toStringAsFixed(2)}, ${propriedade.longitude.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Atualizar clima',
                  onPressed: carregando ? null : onAtualizar,
                  icon: carregando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (carregando && clima == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Consultando previsão climática em tempo real...'),
              )
            else if (erro != null && clima == null)
              Row(
                children: [
                  Icon(Icons.cloud_off, color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      erro!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                ],
              )
            else if (clima != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _ClimaChip(
                        icon: Icons.thermostat_outlined,
                        label: 'Temp.',
                        value: '${clima!.temperaturaC.toStringAsFixed(1)} °C',
                      ),
                      const SizedBox(width: 8),
                      _ClimaChip(
                        icon: Icons.water_outlined,
                        label: 'Umid. Ar',
                        value: '${clima!.umidadeAr}%',
                      ),
                      const SizedBox(width: 8),
                      _ClimaChip(
                        icon: Icons.grain,
                        label: 'Chuva',
                        value: '${clima!.precipitacaoMm.toStringAsFixed(1)} mm',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${clima!.descricaoClima} • Vento ${clima!.ventoKmh.toStringAsFixed(1)} km/h • Atualizado às ${AgroFormatters.formatDateTime(clima!.atualizadoEm)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              )
            else
              const Text('Toque em atualizar para consultar o clima atual.'),
          ],
        ),
      ),
    );
  }
}

class _ClimaChip extends StatelessWidget {
  const _ClimaChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F8E9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: const Color(0xFF1B5E20)),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
