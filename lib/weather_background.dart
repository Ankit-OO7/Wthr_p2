import 'package:flutter/material.dart';

/// The app's plain (untinted) backgrounds.
const lightBase = Color(0xFFF7F7F5);
const darkBase = Color(0xFF0E0F12);

const _nightIndigo = Color(0xFF3949AB);

/// The colour a condition leans towards (a WMO weather code from Open-Meteo).
Color tintHue(int code, {required bool isDay}) {
  final Color day;
  if (code == 0) {
    day = const Color(0xFFF5B301); // clear: warm amber
  } else if (code == 1 || code == 2) {
    day = const Color(0xFF7FA6D6); // partly cloudy: sky
  } else if (code == 3) {
    day = const Color(0xFF8D99A6); // overcast: grey-blue
  } else if (code == 45 || code == 48) {
    day = const Color(0xFF9AA5B1); // fog: pale grey
  } else if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    day = const Color(0xFF3F7FD0); // drizzle and rain: blue
  } else if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    day = const Color(0xFF6FC3E8); // snow: icy cyan
  } else if (code >= 95 && code <= 99) {
    day = const Color(0xFF7E57C2); // thunderstorm: violet
  } else {
    day = const Color(0xFF8D99A6);
  }
  // At night every condition shifts towards deep indigo.
  return isDay ? day : Color.lerp(day, _nightIndigo, 0.6)!;
}

/// The two colours of the background gradient (top, then bottom).
///
/// With no weather yet ([code] null) both are the plain base colour. The tint
/// is strongest at the top and fades towards the bottom, and it is kept
/// gentler in light mode so text and icons stay easy to read.
List<Color> backgroundColors({
  required int? code,
  required bool isDay,
  required Brightness brightness,
}) {
  final dark = brightness == Brightness.dark;
  final base = dark ? darkBase : lightBase;
  if (code == null) return [base, base];

  final hue = tintHue(code, isDay: isDay);
  final topAmount = dark ? 0.26 : 0.17;
  final bottomAmount = dark ? 0.05 : 0.04;
  return [
    Color.lerp(base, hue, topAmount)!,
    Color.lerp(base, hue, bottomAmount)!,
  ];
}
