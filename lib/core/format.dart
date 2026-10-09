// Formatting shared across the app, so dates and counts read the same
// everywhere.

/// `2026-10-08  09:30`, in local time.
String formatDateTime(DateTime dt) {
  final t = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}  '
      '${two(t.hour)}:${two(t.minute)}';
}

/// `1 note`, `3 notes`.
String countOf(int n, String singular, String plural) =>
    '$n ${n == 1 ? singular : plural}';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdaysLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _monthsLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// `Mon`.
String weekdayShort(DateTime day) => _weekdays[day.weekday - 1];

/// `Thu, 9 Oct` (with the year if it isn't [today]'s).
String formatDay(DateTime day, {required DateTime today}) =>
    '${weekdayShort(day)}, ${day.day} ${_months[day.month - 1]}'
    '${day.year == today.year ? '' : ' ${day.year}'}';

/// `Thursday 9 October 2026`, for screen readers.
String formatDayLong(DateTime day) => '${_weekdaysLong[day.weekday - 1]} '
    '${day.day} ${_monthsLong[day.month - 1]} ${day.year}';

/// The local date of [moment], at midnight.
DateTime dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

/// [day] moved by [days] calendar days (safe across daylight saving).
DateTime addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// Whole calendar days from [from] to [to].
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;
