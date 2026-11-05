import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_weather/weather_background.dart';

void main() {
  test('is plain before any weather is loaded', () {
    expect(
      backgroundColors(code: null, isDay: true, brightness: Brightness.light),
      [lightBase, lightBase],
    );
    expect(
      backgroundColors(code: null, isDay: true, brightness: Brightness.dark),
      [darkBase, darkBase],
    );
  });

  test('tints the top more than the bottom', () {
    final colors =
        backgroundColors(code: 63, isDay: true, brightness: Brightness.light);

    expect(colors[0], isNot(lightBase));
    expect(colors[0], isNot(colors[1]));
  });

  test('different conditions get different tints', () {
    Color top(int code) =>
        backgroundColors(code: code, isDay: true, brightness: Brightness.dark)
            .first;

    final tints = {top(0), top(3), top(63), top(73), top(95)};

    expect(tints, hasLength(5));
  });

  test('rain codes share the rain tint', () {
    expect(tintHue(61, isDay: true), tintHue(82, isDay: true));
    expect(tintHue(51, isDay: true), tintHue(65, isDay: true));
  });

  test('night looks different from day', () {
    for (final code in [0, 3, 63]) {
      expect(
        tintHue(code, isDay: false),
        isNot(tintHue(code, isDay: true)),
      );
    }
  });

  test('colours are always fully opaque', () {
    for (final code in [0, 1, 3, 45, 51, 63, 73, 95, 999]) {
      for (final isDay in [true, false]) {
        for (final brightness in Brightness.values) {
          for (final color in backgroundColors(
              code: code, isDay: isDay, brightness: brightness)) {
            expect(color.a, 1.0);
          }
        }
      }
    }
  });
}
