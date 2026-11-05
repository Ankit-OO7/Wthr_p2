import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'place.dart';

/// One hour of forecast. [time] holds the place's local wall-clock time in
/// its fields (it is flagged UTC only so the fields are read as-is).
class HourlyForecast {
  const HourlyForecast({
    required this.time,
    required this.temperatureC,
    required this.code,
    required this.isDay,
    this.rainChance,
  });

  final DateTime time;
  final double temperatureC;
  final int code;
  final bool isDay;

  /// Probability of rain, 0 to 100.
  final int? rainChance;
}

/// One day of forecast. Times are the place's local wall-clock time.
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.code,
    required this.maxC,
    required this.minC,
    this.rainChance,
    this.sunrise,
    this.sunset,
  });

  final DateTime date;
  final int code;
  final double maxC;
  final double minC;
  final int? rainChance;
  final DateTime? sunrise;
  final DateTime? sunset;
}

/// Current conditions plus forecast for one place.
class Weather {
  const Weather({
    required this.place,
    required this.temperatureC,
    required this.code,
    required this.isDay,
    required this.utcOffsetSeconds,
    this.hourly = const [],
    this.daily = const [],
    this.uvIndex,
    this.aqi,
  });

  final Place place;
  final double temperatureC;
  final int code;
  final bool isDay;

  /// The place's offset from UTC, in seconds (19800 for India).
  final int utcOffsetSeconds;

  /// The next 24 hours, starting with the current hour.
  final List<HourlyForecast> hourly;

  /// Up to 7 days, starting with today.
  final List<DailyForecast> daily;

  final double? uvIndex;

  /// US AQI, or null when air quality data isn't available.
  final int? aqi;

  DateTime? get sunrise => daily.isEmpty ? null : daily.first.sunrise;
  DateTime? get sunset => daily.isEmpty ? null : daily.first.sunset;
}

/// An error with a message that is safe to show to the person.
class WeatherException implements Exception {
  const WeatherException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Looks places up and fetches their weather from Open-Meteo
/// (free, no API key).
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 10);

  /// Places matching [query], best match first. Empty when nothing matches.
  Future<List<Place>> searchPlaces(String query, {int count = 5}) async {
    final name = query.trim();
    if (name.isEmpty) {
      throw const WeatherException('Type a place to search.');
    }
    final json = await _getJson(
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': name,
        'count': '$count',
        'language': 'en',
        'format': 'json',
      }),
      failure: 'Location search failed. Try again.',
    );
    final results = json['results'] as List<dynamic>?;
    if (results == null) return const [];

    // Drop near-duplicates so the suggestion list stays tidy.
    final seen = <String>{};
    final places = <Place>[];
    for (final item in results) {
      final place = Place.fromGeocoding(item as Map<String, dynamic>);
      if (seen.add(place.id)) places.add(place);
    }
    return places;
  }

  /// Current weather and forecast at [place].
  Future<Weather> weatherFor(Place place) async {
    // Air quality is a nice extra: start it now, and never let it fail the
    // whole request.
    final aqiFuture = _fetchAqi(place);

    final json = await _getJson(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${place.latitude}',
        'longitude': '${place.longitude}',
        'current': 'temperature_2m,weather_code,is_day,uv_index',
        'hourly': 'temperature_2m,weather_code,is_day,precipitation_probability',
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min,'
            'precipitation_probability_max,sunrise,sunset',
        'forecast_days': '7',
        'timezone': 'auto',
      }),
      failure: 'Weather is unavailable. Try again.',
    );

    try {
      final current = json['current'] as Map<String, dynamic>;
      return Weather(
        place: place,
        temperatureC: (current['temperature_2m'] as num).toDouble(),
        code: (current['weather_code'] as num).toInt(),
        isDay: (current['is_day'] as num) == 1,
        utcOffsetSeconds: (json['utc_offset_seconds'] as num?)?.toInt() ?? 0,
        uvIndex: (current['uv_index'] as num?)?.toDouble(),
        hourly: _parseHourly(
          json['hourly'] as Map<String, dynamic>?,
          current['time'] as String?,
        ),
        daily: _parseDaily(json['daily'] as Map<String, dynamic>?),
        aqi: await aqiFuture,
      );
    } catch (_) {
      throw const WeatherException('Weather is unavailable. Try again.');
    }
  }

  Future<int?> _fetchAqi(Place place) async {
    try {
      final json = await _getJson(
        Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
          'latitude': '${place.latitude}',
          'longitude': '${place.longitude}',
          'current': 'us_aqi',
          'timezone': 'auto',
        }),
        failure: 'Air quality is unavailable.',
      );
      final current = json['current'] as Map<String, dynamic>?;
      return (current?['us_aqi'] as num?)?.round();
    } catch (_) {
      return null;
    }
  }

  /// Parses an Open-Meteo local time ("2026-11-04T18:00" or "2026-11-04")
  /// into a DateTime whose fields are that wall-clock time.
  static DateTime _local(String s) =>
      DateTime.parse(s.length == 10 ? '${s}T00:00:00Z' : '${s}Z');

  static List<HourlyForecast> _parseHourly(
      Map<String, dynamic>? hourly, String? nowLocal) {
    if (hourly == null) return const [];
    final times = List<String>.from(hourly['time'] as List<dynamic>? ?? []);
    final temps = hourly['temperature_2m'] as List<dynamic>? ?? const [];
    final codes = hourly['weather_code'] as List<dynamic>? ?? const [];
    final days = hourly['is_day'] as List<dynamic>? ?? const [];
    final rain =
        hourly['precipitation_probability'] as List<dynamic>? ?? const [];

    // Start at the current hour ("2026-11-04T18:45" -> "2026-11-04T18:00").
    final key = (nowLocal != null && nowLocal.length >= 13)
        ? '${nowLocal.substring(0, 13)}:00'
        : '';
    var start = times.indexWhere((t) => t.compareTo(key) >= 0);
    if (start < 0) start = 0;
    final end = math.min(start + 24, times.length);

    final result = <HourlyForecast>[];
    for (var i = start; i < end; i++) {
      final temp = i < temps.length ? temps[i] as num? : null;
      final code = i < codes.length ? codes[i] as num? : null;
      if (temp == null || code == null) continue;
      result.add(HourlyForecast(
        time: _local(times[i]),
        temperatureC: temp.toDouble(),
        code: code.toInt(),
        isDay: i < days.length ? (days[i] as num?) == 1 : true,
        rainChance: i < rain.length ? (rain[i] as num?)?.round() : null,
      ));
    }
    return result;
  }

  static List<DailyForecast> _parseDaily(Map<String, dynamic>? daily) {
    if (daily == null) return const [];
    final times = List<String>.from(daily['time'] as List<dynamic>? ?? []);
    final codes = daily['weather_code'] as List<dynamic>? ?? const [];
    final maxes = daily['temperature_2m_max'] as List<dynamic>? ?? const [];
    final mins = daily['temperature_2m_min'] as List<dynamic>? ?? const [];
    final rain =
        daily['precipitation_probability_max'] as List<dynamic>? ?? const [];
    final rises = daily['sunrise'] as List<dynamic>? ?? const [];
    final sets = daily['sunset'] as List<dynamic>? ?? const [];

    final result = <DailyForecast>[];
    for (var i = 0; i < times.length; i++) {
      final max = i < maxes.length ? maxes[i] as num? : null;
      final min = i < mins.length ? mins[i] as num? : null;
      final code = i < codes.length ? codes[i] as num? : null;
      if (max == null || min == null || code == null) continue;
      final rise = i < rises.length ? rises[i] as String? : null;
      final set = i < sets.length ? sets[i] as String? : null;
      result.add(DailyForecast(
        date: _local(times[i]),
        code: code.toInt(),
        maxC: max.toDouble(),
        minC: min.toDouble(),
        rainChance: i < rain.length ? (rain[i] as num?)?.round() : null,
        sunrise: rise == null ? null : _local(rise),
        sunset: set == null ? null : _local(set),
      ));
    }
    return result;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri,
      {required String failure}) async {
    try {
      final res = await _client.get(uri).timeout(_timeout);
      if (res.statusCode != 200) throw WeatherException(failure);
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on WeatherException {
      rethrow;
    } on TimeoutException {
      throw const WeatherException('That took too long. Try again.');
    } on http.ClientException {
      throw const WeatherException('No connection. Check your internet.');
    } catch (_) {
      throw const WeatherException('Something went wrong. Try again.');
    }
  }
}
