import 'package:flutter/material.dart';

/// A named band (e.g. "Moderate") with the colour that goes with it.
class Level {
  const Level(this.label, this.color);

  final String label;
  final Color color;
}

/// UV index bands, as used by the WHO.
Level uvLevel(double uv) {
  final value = uv.round();
  if (value <= 2) return const Level('Low', Color(0xFF43A047));
  if (value <= 5) return const Level('Moderate', Color(0xFFF9A825));
  if (value <= 7) return const Level('High', Color(0xFFEF6C00));
  if (value <= 10) return const Level('Very high', Color(0xFFE53935));
  return const Level('Extreme', Color(0xFF8E24AA));
}

/// US AQI bands.
Level aqiLevel(int aqi) {
  if (aqi <= 50) return const Level('Good', Color(0xFF43A047));
  if (aqi <= 100) return const Level('Moderate', Color(0xFFF9A825));
  if (aqi <= 150) return const Level('Unhealthy for some', Color(0xFFEF6C00));
  if (aqi <= 200) return const Level('Unhealthy', Color(0xFFE53935));
  if (aqi <= 300) return const Level('Very unhealthy', Color(0xFF8E24AA));
  return const Level('Hazardous', Color(0xFF7B1E3A));
}
