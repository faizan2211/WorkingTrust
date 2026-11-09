/// The rows the profile's section routes store, and the date helpers the
/// employment and certification forms need.
///
/// Every row carries the `id` the backend gave it: `POST /api/profile/…`
/// answers with `{item}`, and `PATCH`/`DELETE /api/profile/…/{id}` only accept
/// that id. An empty [id] means the row exists on this device only.
/// `GET /api/profile` lists all of them, so a row written elsewhere arrives with
/// its id and can be edited or removed from here.
library;

import 'dart:typed_data';

/// A language the profile speaks. `proficiency` is the backend's name for
/// [Language.level].
typedef Language = ({String id, String name, String level});

typedef Education = ({String id, String institution, String degree});

typedef Certification = ({
  String id,
  String title,
  String provider,
  String issued,
  String credentialId,
  String description,
});

/// [period] is the text the app shows for the picked dates; [startDate] and
/// [endDate] are the ISO dates the route stores, and [endDate] is empty while
/// the job is still running.
typedef Employment = ({
  String id,
  String role,
  String company,
  String period,
  String startDate,
  String endDate,
  String description,
});

/// A completed or running order shown under "Work History".
///
/// No profile route stores these: the rows come from the account's orders, and
/// the app has no endpoint that returns them, so the section can only ever show
/// what this device was told about.
typedef WorkHistoryJob = ({
  String title,
  double rating,
  int reviews,
  String period,
  String review,
  String amount,
  String pricing,
  bool inProgress,
});

/// A published project. [image] is the URL the media route stored, [kind] is
/// the backend's own `mediaType`, and [status] is `DRAFT` or `PUBLISHED`.
typedef PortfolioItem = ({
  String id,
  String title,
  String image,
  String kind,
  String link,
  String status,
  String role,
  List<String> skills,
  String description,
});

/// What the portfolio form hands over before anything is stored: the fields
/// plus the picked file, if the project has one. [kind] is the block type the
/// project is made of, in the backend's own `mediaType` words.
typedef PortfolioDraft = ({
  String title,
  String role,
  List<String> skills,
  String description,
  String link,
  String status,
  String kind,
  Uint8List? bytes,
  String filename,
  String mimeType,
});

/// Everything one account's profile holds, as `GET /api/profile` answers it and
/// as this device keeps its copy of that.
///
/// The identity — name, email, role — comes from the session on every load, and
/// the two-step switches and notification preferences have their own GET
/// routes, so none of those are kept here.
typedef ProfileSnapshot = ({
  String title,
  String hourlyRate,
  String bio,
  List<String> skills,
  String avatarUrl,
  String videoIntro,
  String githubUrl,
  String websiteUrl,
  String youtubeUrl,
  List<Language> languages,
  List<Education> education,
  List<Certification> certifications,
  List<Employment> employment,
  List<PortfolioItem> portfolio,
});

const List<String> _months = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

/// `2026-08-10`, the form the employment route stores a date in.
String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${_pair('${date.month}')}'
    '-${_pair('${date.day}')}';

/// A date the route stored, or null when the row has none.
DateTime? dateFromIso(String text) => DateTime.tryParse(text.trim());

/// The line a card shows for a picked range. A blank end is a job still
/// running, which is exactly what the route's empty `endDate` means.
String periodLabel(DateTime start, DateTime? end) =>
    '${dateLabel(start)} – ${end == null ? 'Present' : dateLabel(end)}';

/// `Aug 10, 2026`, the form a date field shows a picked day in.
String dateLabel(DateTime date) {
  final month = _months[date.month - 1];
  return '${month[0].toUpperCase()}${month.substring(1)} ${date.day}, '
      '${date.year}';
}

/// `August 10, 2026`, `Aug 2024`, `2026-08-10` and a bare `2026` all become an
/// ISO date; anything without a year returns null.
///
/// The backend runs these values through `new Date()`, so an unreadable text
/// must never reach it — it either 400s or, worse for a certification, is
/// stored as an invalid date.
String? isoDateFromText(String text) {
  final trimmed = text.trim();
  final year = RegExp(r'\b(\d{4})\b').firstMatch(trimmed)?.group(1);
  if (year == null) return null;
  final lower = trimmed.toLowerCase();
  var month = 0;
  for (var index = 0; index < _months.length; index++) {
    if (RegExp('\\b${_months[index]}[a-z]*\\b').hasMatch(lower)) {
      month = index + 1;
      break;
    }
  }
  if (month == 0) {
    final iso = RegExp(r'\d{4}-(\d{1,2})-(\d{1,2})').firstMatch(trimmed);
    if (iso != null) {
      return '$year-${_pair(iso.group(1))}-${_pair(iso.group(2))}';
    }
    final slash = RegExp(r'(\d{1,2})/(\d{1,2})/\d{4}').firstMatch(trimmed);
    if (slash != null) {
      return '$year-${_pair(slash.group(1))}-${_pair(slash.group(2))}';
    }
    return '$year-01-01';
  }
  final day = RegExp(r'\b(\d{1,2})\b')
      .firstMatch(trimmed.replaceAll(year, ' '))
      ?.group(1);
  return '$year-${_pair('$month')}-${_pair(day ?? '1')}';
}

String _pair(String? value) => (value ?? '1').padLeft(2, '0');
