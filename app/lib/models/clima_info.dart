/// Dados meteorológicos em tempo real obtidos via API Open-Meteo.
class ClimaInfo {
  const ClimaInfo({
    required this.temperaturaC,
    required this.umidadeAr,
    required this.precipitacaoMm,
    required this.ventoKmh,
    required this.descricaoClima,
    required this.atualizadoEm,
  });

  final double temperaturaC;
  final int umidadeAr;
  final double precipitacaoMm;
  final double ventoKmh;
  final String descricaoClima;
  final DateTime atualizadoEm;

  /// Converte o código meteorológico WMO da API Open-Meteo para português.
  static String descreverWeatherCode(int? code) {
    if (code == null) return 'Condição indisponível';
    if (code == 0) return 'Céu limpo';
    if (code <= 3) return 'Parcialmente nublado';
    if (code <= 48) return 'Neblina';
    if (code <= 57) return 'Garoa';
    if (code <= 67) return 'Chuva';
    if (code <= 77) return 'Granizo / Neve';
    if (code <= 82) return 'Pancadas de chuva';
    if (code <= 99) return 'Tempestade';
    return 'Tempo variável';
  }
}

