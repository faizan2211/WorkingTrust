import 'json_read.dart';

/// The merged money feed from `GET /api/reports/transactions`, already filtered
/// and paged by the server.
///
/// `rows` carries only the current page; `total` and `totalPages` describe the
/// whole filtered feed, so a screen can say how many more rows exist rather
/// than pretending a page is everything.
typedef TransactionFeed = ({
  double? availableBalance,
  double? pendingEarnings,
  bool hasPaymentMethod,
  List<TransactionRow> rows,
  List<String> clients,
  int total,
  int page,
  int limit,
  int totalPages,
});

/// One line in that feed, in the server's own categories.
typedef TransactionRow = ({
  String id,
  DateTime? at,
  String type,
  String details,
  String? client,
  String? status,
  double? amount,
  bool isCredit,
});

/// The five categories the route accepts for `type`, plus its `Earning` alias
/// for `Client`, with the labels the screen lists them under.
enum TransactionFilter {
  all('all', 'All Types'),
  earning('Earning', 'Earning'),
  bids('Bids', 'Bids'),
  subscription('Subscription', 'Subscription'),
  withdrawal('Withdrawal', 'Withdrawal'),
  client('Client', 'Client'),
  other('Other', 'Other');

  const TransactionFilter(this.query, this.label);

  /// The value the `type` parameter takes.
  final String query;

  /// The label in the dropdown.
  final String label;

  static List<String> get labels =>
      TransactionFilter.values.map((f) => f.label).toList(growable: false);

  static TransactionFilter fromLabel(String label) => TransactionFilter.values
      .firstWhere((f) => f.label == label, orElse: () => TransactionFilter.all);
}

TransactionFeed transactionsFromJson(Map<String, dynamic> json) => (
  availableBalance: jsonAmount(json['availableBalance']),
  pendingEarnings: jsonAmount(json['pendingEarnings']),
  hasPaymentMethod: jsonFlag(json['hasPaymentMethod']),
  rows: [
    for (final row in jsonRows(json['rows']))
      if (jsonText(row['id']).isNotEmpty)
        (
          id: jsonText(row['id']),
          at: jsonDate(row['date']),
          type: jsonText(row['type']),
          details: jsonText(row['details']),
          client: jsonText(row['client']).isNotEmpty
              ? jsonText(row['client'])
              : null,
          status: jsonText(row['status']).isNotEmpty
              ? jsonText(row['status'])
              : null,
          amount: jsonAmount(row['amount']),
          isCredit: jsonText(row['amountSign']) == 'credit',
        ),
  ],
  clients: [
    if (json['clients'] is List)
      for (final name in json['clients'] as List)
        if (name is String && name.trim().isNotEmpty) name.trim(),
  ],
  total: jsonCount(json['total']) ?? 0,
  page: jsonCount(json['page']) ?? 1,
  limit: jsonCount(json['limit']) ?? 50,
  totalPages: jsonCount(json['totalPages']) ?? 1,
);

extension TransactionRowText on TransactionRow {
  String get dateLabel => at == null ? '—' : shortDate(at!);

  /// The route hands every amount as a positive number and says which way it
  /// went in `amountSign`, so the sign is applied here rather than guessed
  /// from the category.
  String get amountLabel {
    final value = amount;
    if (value == null) return '—';
    return isCredit ? usd(value) : '-${usd(value)}';
  }
}
