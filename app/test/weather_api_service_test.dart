import 'package:agro_campo/services/weather_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('WeatherApiService', () {
    test('faz parsing correto do clima atual retornado pela API Open-Meteo',
        () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'api.open-meteo.com');
        return http.Response(
          '''
          {
            "current": {
              "temperature_2m": 27.4,
              "relative_humidity_2m": 61,
              "precipitation": 0.2,
              "weather_code": 2,
              "wind_speed_10m": 11.5
            }
          }
          ''',
          200,
        );
      });

      final service = WeatherApiService(client: mockClient);
      final clima = await service.buscarClimaAtual(
        latitude: -21.1775,
        longitude: -47.8103,
      );

      expect(clima.temperaturaC, 27.4);
      expect(clima.umidadeAr, 61);
      expect(clima.precipitacaoMm, 0.2);
      expect(clima.ventoKmh, 11.5);
      expect(clima.descricaoClima, 'Parcialmente nublado');
    });

    test('lança WeatherApiException quando API retorna erro HTTP', () async {
      final mockClient = MockClient(
        (_) async => http.Response('Service Unavailable', 503),
      );
      final service = WeatherApiService(client: mockClient);

      expect(
        () => service.buscarClimaAtual(latitude: -21.0, longitude: -47.0),
        throwsA(isA<WeatherApiException>()),
      );
    });

    test('geocodifica município priorizando resultado no Brasil', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'geocoding-api.open-meteo.com');
        return http.Response(
          '''
          {
            "results": [
              {
                "name": "Londrina",
                "latitude": -23.3103,
                "longitude": -51.1628,
                "country_code": "BR",
                "admin1": "Paraná"
              }
            ]
          }
          ''',
          200,
        );
      });

      final service = WeatherApiService(client: mockClient);
      final geo = await service.geocodificarMunicipio('Londrina', 'PR');

      expect(geo, isNotNull);
      expect(geo!.latitude, closeTo(-23.3103, 0.001));
      expect(geo.longitude, closeTo(-51.1628, 0.001));
      expect(geo.nomeResolvido, 'Londrina (Paraná)');
    });
  });
}

