import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_weather/levels.dart';

void main() {
  test('UV bands', () {
    expect(uvLevel(0).label, 'Low');
    expect(uvLevel(2.4).label, 'Low');
    expect(uvLevel(4.6).label, 'Moderate');
    expect(uvLevel(6).label, 'High');
    expect(uvLevel(9).label, 'Very high');
    expect(uvLevel(11).label, 'Extreme');
  });

  test('AQI bands', () {
    expect(aqiLevel(30).label, 'Good');
    expect(aqiLevel(82).label, 'Moderate');
    expect(aqiLevel(120).label, 'Unhealthy for some');
    expect(aqiLevel(180).label, 'Unhealthy');
    expect(aqiLevel(250).label, 'Very unhealthy');
    expect(aqiLevel(400).label, 'Hazardous');
  });
}
