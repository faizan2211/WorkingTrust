/// Reading the wallet, reports and proposals routes answers with numbers and
/// dates in the column names the backend stores, so the same three checks are
/// written here once instead of in every model.
///
/// A field that is absent or of the wrong type reads as nothing rather than as
/// zero, because a financial row that silently shows `$0.00` for a column the
/// server never sent is a wrong number, not an empty one.
library;

String jsonText(Object? value) => value is String ? value.trim() : '';

/// A number column, or null when the row did not carry one.
double? jsonAmount(Object? value) => value is num ? value.toDouble() : null;

/// A number column that counts things — connects, bids, page sizes.
int? jsonCount(Object? value) => value is num ? value.round() : null;

/// An ISO timestamp from `Date#toISOString()`, as UTC.
DateTime? jsonDate(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

/// A boolean column that was stored as one.
bool jsonFlag(Object? value) => value == true;

/// The rows of a JSON list, skipping anything that is not an object.
List<Map<String, dynamic>> jsonRows(Object? value) => [
  if (value is List)
    for (final row in value)
      if (row is Map<String, dynamic>) row,
];

/// Money as the app writes it: two decimals, always in dollars.
String usd(double amount) => '\$${amount.toStringAsFixed(2)}';

/// A date the way the website's own short format writes it — `Mar 5, 2026`.
String shortDate(DateTime date) {
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
  final local = date.toLocal();
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

/// A date with the time on it, for a ledger row two entries can share.
String shortDateTime(DateTime date) {
  final local = date.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final half = local.hour < 12 ? 'AM' : 'PM';
  return '${shortDate(local)} · $hour12:$minute $half';
}
