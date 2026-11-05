/// The wall-clock time at a place with the given UTC offset.
///
/// The returned [DateTime] is flagged UTC only so that its fields (hour,
/// day...) can be read directly; they hold the *local* time at the place.
DateTime localNow(int utcOffsetSeconds, {DateTime? nowUtc}) {
  final utc = (nowUtc ?? DateTime.now()).toUtc();
  return utc.add(Duration(seconds: utcOffsetSeconds));
}

/// "GMT+5:30", "GMT-8", or "GMT" for zero.
String gmtLabel(int utcOffsetSeconds) {
  if (utcOffsetSeconds == 0) return 'GMT';
  final sign = utcOffsetSeconds < 0 ? '-' : '+';
  final abs = utcOffsetSeconds.abs();
  final hours = abs ~/ 3600;
  final minutes = (abs % 3600) ~/ 60;
  if (minutes == 0) return 'GMT$sign$hours';
  return 'GMT$sign$hours:${minutes.toString().padLeft(2, '0')}';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

int _hour12(DateTime t) => t.hour % 12 == 0 ? 12 : t.hour % 12;

/// "6:21 PM"
String clockLabel(DateTime t) {
  final minute = t.minute.toString().padLeft(2, '0');
  return '${_hour12(t)}:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "6 PM" (for the hourly strip).
String hourLabel(DateTime t) => '${_hour12(t)} ${t.hour < 12 ? 'AM' : 'PM'}';

/// "Fri"
String dayLabel(DateTime t) => _weekdays[t.weekday - 1];

/// "Fri, 30 Oct, 6:21 PM" for a local time from [localNow].
String formatLocal(DateTime t) =>
    '${dayLabel(t)}, ${t.day} ${_months[t.month - 1]}, ${clockLabel(t)}';
