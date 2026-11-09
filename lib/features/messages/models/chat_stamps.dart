/// How a message time is written down, in the three places it appears.
library;

/// The list row's stamp: a time for today, a date for anything older.
String chatStamp(DateTime at, {DateTime? now}) {
  final today = now ?? DateTime.now();
  if (at.year == today.year && at.month == today.month && at.day == today.day) {
    return chatTimeLabel(at);
  }
  return chatDayLabel(at, now: today);
}

/// `3:45 pm`, the line under a bubble.
String chatTimeLabel(DateTime at) {
  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final minute = at.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${at.hour < 12 ? 'am' : 'pm'}';
}

/// The divider above a day's messages: `Today`, `Yesterday`, or the date.
String chatDayLabel(DateTime at, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = DateTime(at.year, at.month, at.day);
  final startOfToday = DateTime(today.year, today.month, today.day);
  final difference = startOfToday.difference(day).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  const months = [
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
  final date = '${months[day.month - 1]} ${day.day}';
  return day.year == startOfToday.year ? date : '$date, ${day.year}';
}
