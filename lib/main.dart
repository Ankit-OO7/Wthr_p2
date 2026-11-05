import 'dart:async';

import 'package:flutter/material.dart';

import 'forecast_widgets.dart';
import 'place.dart';
import 'storage.dart';
import 'time_format.dart';
import 'weather_background.dart';
import 'weather_code.dart';
import 'weather_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await Storage.open();
  runApp(WeatherApp(storage: storage));
}

class WeatherApp extends StatefulWidget {
  const WeatherApp({super.key, required this.storage});

  final Storage storage;

  @override
  State<WeatherApp> createState() => _WeatherAppState();
}

class _WeatherAppState extends State<WeatherApp> {
  late ThemeMode _mode = widget.storage.themeMode();

  void _setMode(ThemeMode mode) {
    setState(() => _mode = mode);
    widget.storage.setThemeMode(mode);
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: dark ? darkBase : lightBase,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4F8CFF),
        brightness: brightness,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: HomePage(
        storage: widget.storage,
        themeMode: _mode,
        onThemeMode: _setMode,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.storage,
    required this.themeMode,
    required this.onThemeMode,
  });

  final Storage storage;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _service = WeatherService();

  /// Whether the search bar is expanded (it starts as just an icon).
  bool _searchOpen = false;

  Weather? _weather;
  String? _error;
  bool _loading = false;

  List<Place> _suggestions = [];
  late List<Place> _saved = widget.storage.savedPlaces();

  Timer? _debounce;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Keep the displayed time fresh.
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _weather != null) setState(() {});
    });
    // Reopen on the last place that was viewed.
    final last = widget.storage.lastPlace();
    if (last != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _select(last));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _clock?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---- search ------------------------------------------------------------

  void _toggleSearch() {
    if (_searchOpen) {
      _closeSearch();
      return;
    }
    _controller.clear();
    setState(() => _searchOpen = true);
    // Wait for the field to exist, then bring up the keyboard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _closeSearch() {
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    setState(() {
      _searchOpen = false;
      _suggestions = [];
    });
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await _service.searchPlaces(query);
        // Ignore answers to a query the person has already moved past.
        if (!mounted || _controller.text.trim() != query) return;
        setState(() => _suggestions = results);
      } on WeatherException {
        if (!mounted) return;
        setState(() => _suggestions = []);
      }
    });
  }

  /// Keyboard "search" button: use the best match for what was typed.
  Future<void> _submit(String query) async {
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _suggestions = [];
    });
    try {
      final results = await _service.searchPlaces(query, count: 1);
      if (!mounted) return;
      if (results.isEmpty) {
        throw WeatherException('No place found for "${query.trim()}".');
      }
      await _select(results.first);
    } on WeatherException catch (e) {
      if (!mounted) return;
      setState(() {
        _weather = null;
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _select(Place place) async {
    FocusScope.of(context).unfocus();
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _searchOpen = false;
      _suggestions = [];
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.weatherFor(place);
      if (!mounted) return;
      setState(() => _weather = result);
      await widget.storage.setLastPlace(place);
    } on WeatherException catch (e) {
      if (!mounted) return;
      setState(() {
        _weather = null;
        _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---- saved places ------------------------------------------------------

  bool _isSaved(Place place) => _saved.any((p) => p.id == place.id);

  Future<void> _toggleSaved(Place place) async {
    final next = [..._saved];
    final index = next.indexWhere((p) => p.id == place.id);
    if (index >= 0) {
      next.removeAt(index);
    } else {
      next.insert(0, place);
    }
    setState(() => _saved = next);
    await widget.storage.setSavedPlaces(next);
  }

  void _openSaved() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) {
          if (_saved.isEmpty) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 40),
              child: Center(
                child: Text(
                  'No saved places yet.\nSearch for a place and tap the star.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              for (final place in _saved)
                ListTile(
                  leading: const Icon(Icons.star_rounded),
                  title: Text(place.name),
                  subtitle:
                      place.subtitle.isEmpty ? null : Text(place.subtitle),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _select(place);
                  },
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () async {
                      await _toggleSaved(place);
                      setSheet(() {});
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ---- theme -------------------------------------------------------------

  static String _modeName(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  // ---- UI ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // A soft tint that follows the weather; plain until a place is loaded.
    final background = backgroundColors(
      code: _weather?.code,
      isDay: _weather?.isDay ?? true,
      brightness: theme.brightness,
    );

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: background,
          ),
        ),
        child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Saved places',
                    onPressed: _openSaved,
                    icon: const Icon(Icons.bookmarks_outlined),
                  ),
                  IconButton(
                    tooltip: _searchOpen ? 'Close search' : 'Search',
                    onPressed: _toggleSearch,
                    icon: Icon(
                      Icons.search_rounded,
                      color: _searchOpen ? theme.colorScheme.primary : null,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<ThemeMode>(
                    tooltip: 'Theme',
                    icon: const Icon(Icons.brightness_6_rounded),
                    onSelected: widget.onThemeMode,
                    itemBuilder: (context) => [
                      for (final mode in ThemeMode.values)
                        CheckedPopupMenuItem<ThemeMode>(
                          value: mode,
                          checked: mode == widget.themeMode,
                          child: Text(_modeName(mode)),
                        ),
                    ],
                  ),
                ],
              ),
              // The search bar grows out of the icon and shrinks back.
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _searchOpen
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          textInputAction: TextInputAction.search,
                          onChanged: _onChanged,
                          onSubmitted: _submit,
                          decoration: InputDecoration(
                            hintText: 'Search a city',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: isDark ? 0.4 : 0.6),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),
              Expanded(
                child: _suggestions.isNotEmpty
                    ? _suggestionList()
                    : (_weather != null && !_loading && _error == null)
                        ? _weatherPage(theme)
                        : Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _body(theme),
                            ),
                          ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _suggestionList() {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8),
      itemCount: _suggestions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final place = _suggestions[index];
        return ListTile(
          leading: const Icon(Icons.place_outlined),
          title: Text(place.name),
          subtitle: place.subtitle.isEmpty ? null : Text(place.subtitle),
          onTap: () => _select(place),
        );
      },
    );
  }

  Widget _body(ThemeData theme) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    if (_loading) {
      return const CircularProgressIndicator(key: ValueKey('loading'));
    }
    if (_error != null) {
      return Text(_error!,
          key: const ValueKey('error'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(color: muted));
    }
    final weather = _weather;
    if (weather == null) {
      return Column(
        key: const ValueKey('empty'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wb_cloudy_rounded, size: 56, color: muted),
          const SizedBox(height: 12),
          Text('Tap the search icon to find a place',
              style: TextStyle(color: muted)),
        ],
      );
    }

    // A loaded place is drawn by _weatherPage, not here.
    return const SizedBox.shrink();
  }

  Widget _hero(Weather weather, ThemeData theme, Color muted) {
    final visual = visualFor(weather.code, isDay: weather.isDay);
    final saved = _isSaved(weather.place);
    final now = localNow(weather.utcOffsetSeconds);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(visual.icon, size: 80, color: visual.color),
        const SizedBox(height: 8),
        Text(
          '${weather.temperatureC.round()}°',
          style: const TextStyle(fontSize: 76, fontWeight: FontWeight.w200),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                weather.place.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: saved ? 'Remove from saved' : 'Save place',
              onPressed: () => _toggleSaved(weather.place),
              icon: Icon(
                saved ? Icons.star_rounded : Icons.star_border_rounded,
                color: saved ? const Color(0xFFF5B301) : muted,
              ),
            ),
          ],
        ),
        Text(visual.label, style: TextStyle(color: muted)),
        const SizedBox(height: 12),
        Text(
          formatLocal(now),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        Text(
          gmtLabel(weather.utcOffsetSeconds),
          style: TextStyle(color: muted),
        ),
      ],
    );
  }

  /// The scrollable page for a loaded place: current weather, then details
  /// and forecasts.
  Widget _weatherPage(ThemeData theme) {
    final weather = _weather!;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return SingleChildScrollView(
      key: ValueKey(weather.place.id),
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        children: [
          _hero(weather, theme, muted),
          const SizedBox(height: 20),
          DetailsRow(weather: weather),
          if (weather.hourly.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionCard(
              title: 'Next 24 hours',
              child: HourlyStrip(hours: weather.hourly),
            ),
          ],
          if (weather.daily.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: '7-day forecast',
              child: DailyList(days: weather.daily),
            ),
          ],
        ],
      ),
    );
  }
}
