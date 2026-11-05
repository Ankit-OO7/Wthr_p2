import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_weather/place.dart';
import 'package:minimal_weather/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tokyo = Place(
  name: 'Tokyo',
  latitude: 35.68,
  longitude: 139.69,
  region: 'Tokyo',
  country: 'Japan',
  countryCode: 'JP',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts empty with system theme', () async {
    final storage = await Storage.open();

    expect(storage.savedPlaces(), isEmpty);
    expect(storage.lastPlace(), isNull);
    expect(storage.themeMode(), ThemeMode.system);
  });

  test('remembers saved places, last place and theme', () async {
    final storage = await Storage.open();

    await storage.setSavedPlaces([_tokyo]);
    await storage.setLastPlace(_tokyo);
    await storage.setThemeMode(ThemeMode.dark);

    final reopened = await Storage.open();
    expect(reopened.savedPlaces().single.name, 'Tokyo');
    expect(reopened.savedPlaces().single.countryCode, 'JP');
    expect(reopened.lastPlace()?.label, 'Tokyo, Japan');
    expect(reopened.themeMode(), ThemeMode.dark);
  });

  test('ignores corrupt stored data', () async {
    SharedPreferences.setMockInitialValues({
      'saved_places': 'not json',
      'last_place': '{',
      'theme_mode': 'purple',
    });
    final storage = await Storage.open();

    expect(storage.savedPlaces(), isEmpty);
    expect(storage.lastPlace(), isNull);
    expect(storage.themeMode(), ThemeMode.system);
  });
}
