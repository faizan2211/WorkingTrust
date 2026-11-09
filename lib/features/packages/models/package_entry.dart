import 'dart:convert';

/// One `Package` row, in the backend's own names.
///
/// Every field here is a column of the `Package` table the Admin Panel writes
/// (`id, name, kind, priceUsd, connects, description, validityDays, features,
/// audience, featured, active, sortOrder, serviceFeePct`), so a row read from an
/// API answer and a row typed into a catalog are the same thing and the screens
/// never have to know which.
typedef PackageEntry = ({
  String id,
  String name,
  PackageKind kind,
  double priceUsd,
  int connects,
  String description,
  int? validityDays,
  List<String> features,
  String audience,
  bool featured,
  bool active,
  int sortOrder,
  double? serviceFeePct,
});

/// What a package is for, which is also the `purpose` the checkout route takes.
enum PackageKind {
  bids('BIDS', 'bids', '/buy-bids'),
  membership('MEMBERSHIP', 'membership', '/deposit');

  const PackageKind(this.column, this.purpose, this.returnTo);

  /// The value the `kind` column holds, which is how a row says what it is.
  final String column;

  /// The `purpose` `POST /api/deposits/stripe/checkout` expects for this kind.
  final String purpose;

  /// The website page Stripe sends the browser back to once the payment ends.
  final String returnTo;

  /// The `kind` of a row, defaulting the way the column's own default does.
  static PackageKind of(String? value) => PackageKind.values.firstWhere(
    (kind) => kind.column == value?.trim().toUpperCase(),
    orElse: () => PackageKind.bids,
  );
}

/// Reads one `Package` row as the backend stores and serializes it: `features`
/// is a JSON array kept in a text column, `priceUsd` and `serviceFeePct` are
/// floats, and every optional column can arrive as null or be left out.
PackageEntry packageFromJson(Map<String, dynamic> row) {
  final rate = row['serviceFeePct'];
  return (
    id: _text(row['id']),
    name: _text(row['name']),
    kind: PackageKind.of(row['kind']),
    priceUsd: _number(row['priceUsd']) ?? 0,
    connects: _number(row['connects'])?.round() ?? 0,
    description: _text(row['description']),
    validityDays: _number(row['validityDays'])?.round(),
    features: _features(row['features']),
    audience: _text(row['audience']),
    featured: row['featured'] == true,
    // A row that never says is a row nobody deactivated.
    active: row['active'] != false,
    sortOrder: _number(row['sortOrder'])?.round() ?? 0,
    serviceFeePct: rate is num ? rate.toDouble() : null,
  );
}

/// How the app words one package. These read only what a row carries, so an
/// absent field simply shows nothing instead of a made-up figure.
extension PackagePresentation on PackageEntry {
  String get priceLabel => '\$${priceUsd.toStringAsFixed(2)}';

  /// The web names a bid pack by the bids it adds, and a plan by the connects it
  /// pays out each period.
  String get connectsLabel =>
      kind == PackageKind.bids ? '$connects Bids' : '$connects connects';

  /// The period the price covers: an explicit validity, or a month for the
  /// subscription the checkout route opens.
  String get periodLabel {
    final days = validityDays;
    if (days == null) return kind == PackageKind.membership ? '/ month' : '';
    return days == 30 ? '/ month' : '/ $days days';
  }

  /// The `audience` label, shown only for the two values the Admin Panel offers.
  String? get audienceLabel => switch (audience.trim().toUpperCase()) {
    'FREELANCER' => 'For freelancers',
    'CLIENT' => 'For clients',
    _ => null,
  };

  String? get serviceFeeLabel => serviceFeePct == null
      ? null
      : '${serviceFeePct! == serviceFeePct!.roundToDouble() ? serviceFeePct!.round() : serviceFeePct}% service fee';

  /// The button under a package.
  String get actionLabel => 'Continue With $name';

  /// The date the package runs out, or null when no validity was stored — in
  /// which case the app promises no expiry it cannot verify.
  DateTime? get expiresOn {
    final days = validityDays;
    return days == null ? null : DateTime.now().add(Duration(days: days));
  }
}

String _text(Object? value) => value is String ? value.trim() : '';

double? _number(Object? value) => value is num ? value.toDouble() : null;

/// `features` is either that JSON string or, as the admin routes hand it, an
/// already-decoded list. Anything else is no features at all.
List<String> _features(Object? value) {
  Object? decoded = value;
  if (decoded is String) {
    final text = decoded.trim();
    if (text.isEmpty) return const [];
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return const [];
    }
  }
  if (decoded is! List) return const [];
  return [
    for (final feature in decoded)
      if (feature is String && feature.trim().isNotEmpty) feature.trim(),
  ];
}
