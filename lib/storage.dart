import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'place.dart';

/// Everything the app remembers between launches.
class Storage {
  Storage(this._prefs);

  final SharedPreferences _prefs;

  static const _savedKey = 'saved_places';
  static const _lastKey = 'last_place';
  static const _themeKey = 'theme_mode';

  static Future<Storage> open() async =>
      Storage(await SharedPreferences.getInstance());

  List<Place> savedPlaces() {
    final raw = _prefs.getString(_savedKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => Place.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return []; // Corrupt data should never stop the app opening.
    }
  }

  Future<void> setSavedPlaces(List<Place> places) => _prefs.setString(
        _savedKey,
        jsonEncode(places.map((p) => p.toJson()).toList()),
      );

  Place? lastPlace() {
    final raw = _prefs.getString(_lastKey);
    if (raw == null) return null;
    try {
      return Place.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setLastPlace(Place place) =>
      _prefs.setString(_lastKey, jsonEncode(place.toJson()));

  ThemeMode themeMode() {
    final name = _prefs.getString(_themeKey);
    return ThemeMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeKey, mode.name);
}
