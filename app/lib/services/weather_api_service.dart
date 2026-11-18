import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/clima_info.dart';

/// Coordenadas geográficas resolvidas para uma propriedade rural.
class GeoCoordinates {
  const GeoCoordinates({
    required this.latitude,
    required this.longitude,
    required this.nomeResolvido,
  });

  final double latitude;
  final double longitude;
  final String nomeResolvido;
}

/// Exceção específica para falhas de comunicação com a API meteorológica.
class WeatherApiException implements Exception {
  WeatherApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Serviço de integração real com a API pública Open-Meteo.
///
/// Finalidade no fluxo agrícola:
/// - Geocodificação do município da propriedade (`geocoding-api.open-meteo.com`).
/// - Consulta de temperatura, umidade relativa do ar, precipitação e vento
///   (`api.open-meteo.com`) para apoiar decisões de irrigação, pulverização e colheita.
class WeatherApiService {
  WeatherApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 10);

  /// Busca latitude e longitude reais a partir do nome do município.
  Future<GeoCoordinates?> geocodificarMunicipio(
    String municipio,
    String estado,
  ) async {
    final query = Uri.encodeQueryComponent(municipio.trim());
    final uri = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search?name=$query&count=5&language=pt&format=json',
    );

    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw WeatherApiException(
          'Erro ao consultar geocodificação (HTTP ${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final results = decoded['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        return null;
      }

      // Prioriza resultados do Brasil quando disponíveis.
      final brazilMatch = results.cast<Map<String, dynamic>>().firstWhere(
            (r) => r['country_code']?.toString().toUpperCase() == 'BR',
            orElse: () => results.first as Map<String, dynamic>,
          );

      final lat = (brazilMatch['latitude'] as num?)?.toDouble();
      final lon = (brazilMatch['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;

      final nome = brazilMatch['name']?.toString() ?? municipio;
      final admin1 = brazilMatch['admin1']?.toString() ?? estado;
      return GeoCoordinates(
        latitude: lat,
        longitude: lon,
        nomeResolvido: '$nome ($admin1)',
      );
    } on TimeoutException {
      throw WeatherApiException(
        'Tempo esgotado ao buscar localização do município.',
      );
    } catch (e) {
      if (e is WeatherApiException) rethrow;
      throw WeatherApiException(
        'Não foi possível consultar a API de geocodificação.',
      );
    }
  }

  /// Consulta as condições climáticas atuais para as coordenadas da propriedade.
  Future<ClimaInfo> buscarClimaAtual({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=${latitude.toStringAsFixed(4)}'
      '&longitude=${longitude.toStringAsFixed(4)}'
      '&current=temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m'
      '&timezone=auto',
    );

    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw WeatherApiException(
          'Falha na API Open-Meteo (HTTP ${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final current = decoded['current'] as Map<String, dynamic>?;
      if (current == null) {
        throw WeatherApiException(
          'Resposta da API Open-Meteo sem dados atuais.',
        );
      }

      final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 0.0;
      final humidity = (current['relative_humidity_2m'] as num?)?.toInt() ?? 0;
      final rain = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
      final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;
      final code = (current['weather_code'] as num?)?.toInt();

      return ClimaInfo(
        temperaturaC: temp,
        umidadeAr: humidity,
        precipitacaoMm: rain,
        ventoKmh: wind,
        descricaoClima: ClimaInfo.descreverWeatherCode(code),
        atualizadoEm: DateTime.now(),
      );
    } on TimeoutException {
      throw WeatherApiException(
        'Tempo limite excedido ao consultar previsão climática.',
      );
    } catch (e) {
      if (e is WeatherApiException) rethrow;
      throw WeatherApiException(
        'Erro de conexão ao consultar condições climáticas na API Open-Meteo.',
      );
    }
  }
}

