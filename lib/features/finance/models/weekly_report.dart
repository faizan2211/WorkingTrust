import 'json_read.dart';

/// The weekly report, as `GET /api/reports/weekly` answers it.
///
/// The freelancer view is one summary of the week; `?scope=client` swaps the
/// body for the same week broken down per client and needs an active Pro plan,
/// so `clients` is empty unless that scope was asked for and allowed.
typedef WeeklyReport = ({
  DateTime? since,
  DateTime? until,
  double? earnings,
  int projects,
  int proposals,
  int approvedCount,
  int submittedCount,
  int messages,
  List<WeeklyClient> clients,
});

typedef WeeklyClient = ({
  String name,
  String profile,
  int jobs,
  int submitted,
  double? earned,
  int proposals,
  int messageCount,
});

/// The report a card on the My Reports screen can offer.
enum WeeklyScope {
  summary('', 'Weekly Summary'),
  client('client', 'Weekly Summary By Client');

  const WeeklyScope(this.query, this.title);

  /// The `scope` parameter the routes take, empty for the freelancer view.
  final String query;
  final String title;

  /// Only the client breakdown is behind a Pro plan.
  bool get needsPro => this == WeeklyScope.client;

  static WeeklyScope of(String title) => WeeklyScope.values.firstWhere(
    (scope) => scope.title == title,
    orElse: () => WeeklyScope.summary,
  );
}

WeeklyReport weeklyFromJson(Map<String, dynamic> json) => (
  since: jsonDate(json['since']),
  until: jsonDate(json['until']),
  earnings: jsonAmount(json['earnings']),
  projects: jsonCount(json['projects']) ?? 0,
  proposals: jsonCount(json['proposals']) ?? 0,
  approvedCount: jsonCount(json['approvedCount']) ?? 0,
  submittedCount: jsonCount(json['submittedCount']) ?? 0,
  messages: jsonCount(json['messages']) ?? 0,
  clients: [
    for (final row in jsonRows(json['clients']))
      if (jsonText(row['name']).isNotEmpty)
        (
          name: jsonText(row['name']),
          profile: jsonText(row['profile']),
          jobs: jsonCount(row['jobs']) ?? 0,
          submitted: jsonCount(row['submitted']) ?? 0,
          earned: jsonAmount(row['earned']),
          proposals: jsonCount(row['proposals']) ?? 0,
          messageCount: jsonCount(row['messageCount']) ?? 0,
        ),
  ],
);

extension WeeklyReportText on WeeklyReport {
  String get earningsLabel => earnings == null ? '—' : usd(earnings!);

  /// The week the report covers. The route sends `since` only, so an end date
  /// is never guessed from it.
  String get rangeLabel {
    final from = since;
    final to = until;
    if (from == null) return 'This week';
    if (to == null) return 'Week of ${shortDate(from)}';
    return '${shortDate(from)} – ${shortDate(to)}';
  }

  /// The figures the preview shows, one line each, all of them the server's.
  List<({String label, String value})> get summaryLines => [
    (label: 'Earnings', value: earningsLabel),
    (label: 'Projects', value: '$projects'),
    (label: 'Proposals sent', value: '$proposals'),
    (label: 'Submitted work', value: '$submittedCount'),
    (label: 'Approved work', value: '$approvedCount'),
    (label: 'Messages', value: '$messages'),
  ];

  List<({String client, String line})> get clientLines => [
    for (final row in clients)
      (
        client: row.name,
        line:
            '${row.jobs} jobs · ${row.submitted} submitted · '
            '${row.messageCount} messages',
      ),
  ];
}

extension WeeklyClientText on WeeklyClient {
  String get earnedLabel => earned == null ? '—' : usd(earned!);
}
