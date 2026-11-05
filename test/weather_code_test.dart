import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_weather/weather_code.dart';

void main() {
  test('clear sky shows the sun by day and the moon by night', () {
    expect(visualFor(0, isDay: true).icon, Icons.wb_sunny_rounded);
    expect(visualFor(0, isDay: false).icon, Icons.nightlight_round);
  });

  test('rain, snow and storms get their own icons', () {
    expect(visualFor(63, isDay: true).label, 'Rain');
    expect(visualFor(81, isDay: true).label, 'Rain');
    expect(visualFor(73, isDay: true).label, 'Snow');
    expect(visualFor(95, isDay: true).label, 'Thunderstorm');
  });

  test('unknown codes fall back safely', () {
    expect(visualFor(999, isDay: true).label, 'Unknown');
  });
}
