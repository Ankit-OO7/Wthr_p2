import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:minimal_weather/place.dart';
import 'package:minimal_weather/weather_service.dart';

Map<String, dynamic> _geo(String name, double lat, double lon,
        {String? region, String country = 'India', String cc = 'IN'}) =>
    {
      'name': name,
      'latitude': lat,
      'longitude': lon,
      'admin1': region,
      'country': country,
      'country_code': cc,
    };

void main() {
  group('searchPlaces', () {
    test('returns suggestions with region and country', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'geocoding-api.open-meteo.com');
        return http.Response(
          jsonEncode({
            'results': [
              _geo('Bengaluru', 12.97, 77.59, region: 'Karnataka'),
              _geo('Bengaluru Rural', 13.2, 77.4, region: 'Karnataka'),
            ]
          }),
          200,
        );
      });

      final places = await WeatherService(client: client).searchPlaces('beng');

      expect(places.map((p) => p.name), ['Bengaluru', 'Bengaluru Rural']);
      expect(places.first.subtitle, 'Karnataka, India');
      expect(places.first.countryCode, 'IN');
    });

    test('drops duplicates at the same spot', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'results': [
                _geo('Paris', 48.85, 2.35, country: 'France', cc: 'FR'),
                _geo('Paris', 48.851, 2.351, country: 'France', cc: 'FR'),
              ]
            }),
            200,
          ));

      final places = await WeatherService(client: client).searchPlaces('paris');

      expect(places, hasLength(1));
    });

    test('is empty when nothing matches', () async {
      final client = MockClient((_) async => http.Response('{}', 200));

      final places = await WeatherService(client: client).searchPlaces('zzzzz');

      expect(places, isEmpty);
    });

    test('rejects an empty search', () {
      final client = MockClient((_) async => http.Response('', 200));

      expect(
        () => WeatherService(client: client).searchPlaces('   '),
        throwsA(isA<WeatherException>()),
      );
    });

    test('turns network failures into a friendly error', () {
      final client =
          MockClient((_) async => throw http.ClientException('offline'));

      expect(
        () => WeatherService(client: client).searchPlaces('Paris'),
        throwsA(isA<WeatherException>()),
      );
    });
  });

  group('weatherFor', () {
    const place = Place(
      name: 'Bengaluru',
      latitude: 12.97,
      longitude: 77.59,
      country: 'India',
    );

    // 48 hourly entries starting 2026-11-04 00:00, one per hour.
    List<String> hourTimes() => [
          for (var i = 0; i < 48; i++)
            '2026-11-${i < 24 ? '04' : '05'}T${(i % 24).toString().padLeft(2, '0')}:00'
        ];

    Map<String, dynamic> forecast() => {
          'utc_offset_seconds': 19800,
          'current': {
            'time': '2026-11-04T18:45',
            'temperature_2m': 26.4,
            'weather_code': 3,
            'is_day': 1,
            'uv_index': 4.6,
          },
          'hourly': {
            'time': hourTimes(),
            'temperature_2m': [for (var i = 0; i < 48; i++) 20.0 + i],
            'weather_code': [for (var i = 0; i < 48; i++) 3],
            'is_day': [for (var i = 0; i < 48; i++) 1],
            'precipitation_probability': [for (var i = 0; i < 48; i++) i],
          },
          'daily': {
            'time': ['2026-11-04', '2026-11-05'],
            'weather_code': [3, 63],
            'temperature_2m_max': [29.2, 27.0],
            'temperature_2m_min': [21.0, 20.4],
            'precipitation_probability_max': [20, 80],
            'sunrise': ['2026-11-04T06:12', '2026-11-05T06:13'],
            'sunset': ['2026-11-04T17:48', '2026-11-05T17:47'],
          },
        };

    MockClient clientWith({int? aqi, bool aqiFails = false}) =>
        MockClient((request) async {
          if (request.url.host == 'air-quality-api.open-meteo.com') {
            if (aqiFails) return http.Response('nope', 500);
            return http.Response(
                jsonEncode({
                  'current': {'us_aqi': aqi}
                }),
                200);
          }
          expect(request.url.host, 'api.open-meteo.com');
          expect(request.url.queryParameters['timezone'], 'auto');
          return http.Response(jsonEncode(forecast()), 200);
        });

    test('returns current weather, offset, UV and AQI', () async {
      final weather =
          await WeatherService(client: clientWith(aqi: 82)).weatherFor(place);

      expect(weather.place.name, 'Bengaluru');
      expect(weather.temperatureC, 26.4);
      expect(weather.code, 3);
      expect(weather.isDay, isTrue);
      expect(weather.utcOffsetSeconds, 19800);
      expect(weather.uvIndex, 4.6);
      expect(weather.aqi, 82);
    });

    test('hourly forecast starts at the current hour and covers 24 hours',
        () async {
      final weather =
          await WeatherService(client: clientWith(aqi: 50)).weatherFor(place);

      expect(weather.hourly, hasLength(24));
      expect(weather.hourly.first.time.hour, 18);
      expect(weather.hourly.first.temperatureC, 38.0); // index 18 -> 20 + 18
      expect(weather.hourly.first.rainChance, 18);
      expect(weather.hourly.last.time.day, 5);
      expect(weather.hourly.last.time.hour, 17);
    });

    test('daily forecast has highs, lows, rain chance and sun times',
        () async {
      final weather =
          await WeatherService(client: clientWith(aqi: 50)).weatherFor(place);

      expect(weather.daily, hasLength(2));
      expect(weather.daily.first.maxC, 29.2);
      expect(weather.daily.first.minC, 21.0);
      expect(weather.daily[1].rainChance, 80);
      expect(weather.daily[1].code, 63);
      expect(weather.sunrise?.hour, 6);
      expect(weather.sunrise?.minute, 12);
      expect(weather.sunset?.hour, 17);
      expect(weather.sunset?.minute, 48);
    });

    test('still works when air quality is unavailable', () async {
      final weather = await WeatherService(client: clientWith(aqiFails: true))
          .weatherFor(place);

      expect(weather.aqi, isNull);
      expect(weather.temperatureC, 26.4);
    });

    test('reports a server error', () {
      final client = MockClient((_) async => http.Response('nope', 500));
      const other = Place(name: 'X', latitude: 0, longitude: 0);

      expect(
        () => WeatherService(client: client).weatherFor(other),
        throwsA(isA<WeatherException>()),
      );
    });
  });
}
