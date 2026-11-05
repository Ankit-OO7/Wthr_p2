import 'package:flutter/material.dart';

import 'levels.dart';
import 'time_format.dart';
import 'weather_code.dart';
import 'weather_service.dart';

const _rainColor = Color(0xFF5B9BD5);

/// Rain chances below this are hidden to keep the lists quiet.
const _minRainToShow = 10;

Color _mutedOf(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

/// A soft rounded panel with a small title.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: isDark ? 0.4 : 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontSize: 13, color: _mutedOf(context))),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// A small pill: coloured dot plus "UV 5 · Moderate".
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.title, required this.level});

  final String title;
  final Level level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: level.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$title · ${level.label}',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// UV and AQI badges, then sunrise and sunset times.
class DetailsRow extends StatelessWidget {
  const DetailsRow({super.key, required this.weather});

  final Weather weather;

  @override
  Widget build(BuildContext context) {
    final muted = _mutedOf(context);
    final uv = weather.uvIndex;
    final aqi = weather.aqi;
    final sunrise = weather.sunrise;
    final sunset = weather.sunset;

    return Column(
      children: [
        if (uv != null || aqi != null)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (uv != null)
                LevelBadge(title: 'UV ${uv.round()}', level: uvLevel(uv)),
              if (aqi != null)
                LevelBadge(title: 'AQI $aqi', level: aqiLevel(aqi)),
            ],
          ),
        if (sunrise != null && sunset != null) ...[
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 6,
            children: [
              _SunTime(
                icon: Icons.wb_twilight_rounded,
                label: 'Sunrise',
                time: clockLabel(sunrise),
                muted: muted,
              ),
              _SunTime(
                icon: Icons.nights_stay_outlined,
                label: 'Sunset',
                time: clockLabel(sunset),
                muted: muted,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SunTime extends StatelessWidget {
  const _SunTime({
    required this.icon,
    required this.label,
    required this.time,
    required this.muted,
  });

  final IconData icon;
  final String label;
  final String time;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 6),
        Text('$label ', style: TextStyle(fontSize: 13, color: muted)),
        Text(time, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

/// A horizontal row of the next hours: time, icon, temperature, rain chance.
class HourlyStrip extends StatelessWidget {
  const HourlyStrip({super.key, required this.hours});

  final List<HourlyForecast> hours;

  @override
  Widget build(BuildContext context) {
    final muted = _mutedOf(context);
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hours.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final hour = hours[index];
          final visual = visualFor(hour.code, isDay: hour.isDay);
          final rain = hour.rainChance;
          return SizedBox(
            width: 44,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  index == 0 ? 'Now' : hourLabel(hour.time),
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                Icon(visual.icon, size: 26, color: visual.color),
                Text(
                  '${hour.temperatureC.round()}°',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
                Text(
                  (rain != null && rain >= _minRainToShow) ? '$rain%' : ' ',
                  style: const TextStyle(fontSize: 11, color: _rainColor),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A compact list: day, icon, rain chance, low and high.
class DailyList extends StatelessWidget {
  const DailyList({super.key, required this.days});

  final List<DailyForecast> days;

  @override
  Widget build(BuildContext context) {
    final muted = _mutedOf(context);
    return Column(
      children: [
        for (var i = 0; i < days.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(i == 0 ? 'Today' : dayLabel(days[i].date)),
                ),
                Icon(
                  visualFor(days[i].code, isDay: true).icon,
                  size: 22,
                  color: visualFor(days[i].code, isDay: true).color,
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 44,
                  child: Text(
                    (days[i].rainChance != null &&
                            days[i].rainChance! >= _minRainToShow)
                        ? '${days[i].rainChance}%'
                        : '',
                    style: const TextStyle(fontSize: 12, color: _rainColor),
                  ),
                ),
                const Spacer(),
                Text('${days[i].minC.round()}°',
                    style: TextStyle(color: muted)),
                const SizedBox(width: 14),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${days[i].maxC.round()}°',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
