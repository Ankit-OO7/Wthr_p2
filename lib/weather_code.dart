import 'package:flutter/material.dart';

/// How a weather condition looks in the UI.
class WeatherVisual {
  const WeatherVisual(this.icon, this.label, this.color);

  final IconData icon;
  final String label;
  final Color color;
}

/// Maps a WMO weather code (as returned by Open-Meteo) to an icon, label and
/// accent colour. [isDay] switches the sun for the moon on clear skies.
WeatherVisual visualFor(int code, {required bool isDay}) {
  if (code == 0) {
    return isDay
        ? const WeatherVisual(
            Icons.wb_sunny_rounded, 'Clear sky', Color(0xFFF5B301))
        : const WeatherVisual(
            Icons.nightlight_round, 'Clear night', Color(0xFF9FA8DA));
  }
  if (code == 1 || code == 2) {
    return const WeatherVisual(
        Icons.wb_cloudy_rounded, 'Partly cloudy', Color(0xFF7FA6D6));
  }
  if (code == 3) {
    return const WeatherVisual(
        Icons.cloud_rounded, 'Overcast', Color(0xFF8D99A6));
  }
  if (code == 45 || code == 48) {
    return const WeatherVisual(Icons.blur_on_rounded, 'Fog', Color(0xFF9AA5B1));
  }
  if (code >= 51 && code <= 57) {
    return const WeatherVisual(
        Icons.grain_rounded, 'Drizzle', Color(0xFF5B9BD5));
  }
  if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
    return const WeatherVisual(
        Icons.water_drop_rounded, 'Rain', Color(0xFF3F7FD0));
  }
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    return const WeatherVisual(
        Icons.ac_unit_rounded, 'Snow', Color(0xFF8FD3F4));
  }
  if (code >= 95 && code <= 99) {
    return const WeatherVisual(
        Icons.bolt_rounded, 'Thunderstorm', Color(0xFF9C6ADE));
  }
  return const WeatherVisual(
      Icons.help_outline_rounded, 'Unknown', Color(0xFF8D99A6));
}
