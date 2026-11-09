import 'json_read.dart';

/// The proposals this account sent, from `GET /api/bids/my`.
///
/// `proposals` is one page of bids, newest first; `activeWork` is the
/// assignments still ACTIVE or SUBMITTED, which is the same split the website's
/// panel makes. `counts` covers every bid the account has ever sent, in each of
/// the four statuses, whatever page or filter is open — so a tab header can
/// show a real number without fetching the whole list.
typedef ProposalFeed = ({
  List<ProposalRow> proposals,
  List<ActiveWorkRow> activeWork,
  BidCounts counts,
  int total,
  int page,
  int limit,
  int totalPages,
});

typedef ProposalRow = ({
  String id,
  String taskId,
  String title,
  String description,
  String status,
  double? bidAmount,
  String proposal,
  int connectsSpent,
  DateTime? at,
  String category,
  String clientName,
  double? earningAmount,
});

typedef ActiveWorkRow = ({
  String id,
  String bidId,
  String taskId,
  String title,
  String status,
  String statusLabel,
  double? payoutAmount,
  DateTime? dueAt,
  DateTime? at,
  String category,
  String clientName,
});

/// The four statuses a bid can hold. The route refuses anything else with a
/// 400, so these are the only filters the screen offers.
enum BidStatus {
  all('all', 'All'),
  pending('PENDING', 'Pending'),
  shortlisted('SHORTLISTED', 'Shortlisted'),
  awarded('AWARDED', 'Awarded'),
  rejected('REJECTED', 'Rejected');

  const BidStatus(this.query, this.label);

  /// The value the `status` parameter takes.
  final String query;
  final String label;

  static List<String> get labels =>
      BidStatus.values.map((s) => s.label).toList(growable: false);

  static BidStatus fromLabel(String label) => BidStatus.values.firstWhere(
    (status) => status.label == label,
    orElse: () => BidStatus.all,
  );

  /// The status as the server's own word, or the raw column when the account
  /// holds something outside the four.
  static String labelOf(String stored) => BidStatus.values
      .firstWhere(
        (status) => status.query == stored.toUpperCase(),
        orElse: () => BidStatus.all,
      )
      .label;
}

typedef BidCounts = ({int pending, int shortlisted, int awarded, int rejected});

ProposalFeed proposalsFromJson(Map<String, dynamic> json) {
  final counts = json['counts'];
  final map = counts is Map<String, dynamic>
      ? counts
      : const <String, dynamic>{};
  return (
    proposals: [
      for (final row in jsonRows(json['proposals']))
        if (jsonText(row['id']).isNotEmpty)
          (
            id: jsonText(row['id']),
            taskId: jsonText(row['taskId']),
            title: jsonText(row['title']),
            description: jsonText(row['description']),
            status: jsonText(row['status']),
            bidAmount: jsonAmount(row['bidAmount']),
            proposal: jsonText(row['proposal']),
            connectsSpent: jsonCount(row['connectsSpent']) ?? 0,
            at: jsonDate(row['createdAt']),
            category: jsonText(row['category']),
            clientName: jsonText(row['clientName']),
            earningAmount: jsonAmount(row['earningAmount']),
          ),
    ],
    activeWork: [
      for (final row in jsonRows(json['activeWork']))
        if (jsonText(row['id']).isNotEmpty)
          (
            id: jsonText(row['id']),
            bidId: jsonText(row['bidId']),
            taskId: jsonText(row['taskId']),
            title: jsonText(row['title']),
            status: jsonText(row['status']),
            statusLabel: jsonText(row['statusLabel']),
            payoutAmount: jsonAmount(row['payoutAmount']),
            dueAt: jsonDate(row['dueAt']),
            at: jsonDate(row['createdAt']),
            category: jsonText(row['category']),
            clientName: jsonText(row['clientName']),
          ),
    ],
    counts: (
      pending: jsonCount(map['PENDING']) ?? 0,
      shortlisted: jsonCount(map['SHORTLISTED']) ?? 0,
      awarded: jsonCount(map['AWARDED']) ?? 0,
      rejected: jsonCount(map['REJECTED']) ?? 0,
    ),
    total: jsonCount(json['total']) ?? 0,
    page: jsonCount(json['page']) ?? 1,
    limit: jsonCount(json['limit']) ?? 20,
    totalPages: jsonCount(json['totalPages']) ?? 1,
  );
}

extension ProposalRowText on ProposalRow {
  String get statusLabel => BidStatus.labelOf(status);

  String get sentLabel => at == null ? '—' : shortDate(at!);

  /// The project pays what the task said; a bid amount the account typed is
  /// only ever an offer, so the earning is what the panel shows.
  String get earningLabel => earningAmount == null ? '—' : usd(earningAmount!);

  String get subtitle => [
    if (clientName.isNotEmpty) clientName,
    if (category.isNotEmpty) category,
    if (connectsSpent > 0) '$connectsSpent connects spent',
  ].join(' · ');
}

extension ActiveWorkRowText on ActiveWorkRow {
  String get payoutLabel => payoutAmount == null ? '—' : usd(payoutAmount!);

  String get dueLabel => dueAt == null ? '—' : shortDate(dueAt!);

  String get subtitle => [
    if (clientName.isNotEmpty) clientName,
    if (category.isNotEmpty) category,
    'Due $dueLabel',
  ].join(' · ');
}
