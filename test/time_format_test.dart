import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_weather/time_format.dart';

void main() {
  group('gmtLabel', () {
    test('formats whole and half hour offsets', () {
      expect(gmtLabel(19800), 'GMT+5:30');
      expect(gmtLabel(20700), 'GMT+5:45');
      expect(gmtLabel(3600), 'GMT+1');
      expect(gmtLabel(-28800), 'GMT-8');
      expect(gmtLabel(-12600), 'GMT-3:30');
    });

    test('is plain GMT at zero', () {
      expect(gmtLabel(0), 'GMT');
    });
  });

  group('localNow', () {
    test('applies the offset to UTC', () {
      final utc = DateTime.utc(2026, 10, 30, 12, 51);

      final india = localNow(19800, nowUtc: utc);

      expect(india.hour, 18);
      expect(india.minute, 21);
    });

    test('rolls over to the next day', () {
      final utc = DateTime.utc(2026, 10, 30, 22, 0);

      final tokyo = localNow(32400, nowUtc: utc);

      expect(tokyo.day, 31);
      expect(tokyo.hour, 7);
    });
  });

  group('formatLocal', () {
    test('formats an evening time', () {
      expect(formatLocal(DateTime.utc(2026, 10, 30, 18, 21)),
          'Fri, 30 Oct, 6:21 PM');
    });

    test('handles midnight and noon', () {
      expect(formatLocal(DateTime.utc(2026, 1, 5, 0, 5)), 'Mon, 5 Jan, 12:05 AM');
      expect(formatLocal(DateTime.utc(2026, 1, 5, 12, 0)), 'Mon, 5 Jan, 12:00 PM');
    });
  });

  group('labels', () {
    test('clockLabel', () {
      expect(clockLabel(DateTime.utc(2026, 11, 4, 6, 5)), '6:05 AM');
      expect(clockLabel(DateTime.utc(2026, 11, 4, 17, 48)), '5:48 PM');
    });

    test('hourLabel', () {
      expect(hourLabel(DateTime.utc(2026, 11, 4, 0)), '12 AM');
      expect(hourLabel(DateTime.utc(2026, 11, 4, 13)), '1 PM');
    });

    test('dayLabel', () {
      expect(dayLabel(DateTime.utc(2026, 11, 4)), 'Wed');
    });
  });
}
