import 'json_read.dart';

/// The Overview page's four figures and its job list, from
/// `GET /api/reports/overview`.
typedef ReportsOverview = ({
  double? workInProgressAmount,
  double? inReviewAmount,
  double? pendingWithdrawalsAmount,
  double? availableBalance,
  List<OverviewJob> jobs,
});

/// One assignment the account is still working on, still waiting on approval
/// for, or has been asked to revise.
typedef OverviewJob = ({
  String id,
  String taskId,
  String title,
  String description,
  String status,
  String statusLabel,
  String clientName,
  double? earningAmount,
  DateTime? dueAt,
});

ReportsOverview overviewFromJson(Map<String, dynamic> json) => (
  workInProgressAmount: jsonAmount(json['workInProgressAmount']),
  inReviewAmount: jsonAmount(json['inReviewAmount']),
  pendingWithdrawalsAmount: jsonAmount(json['pendingWithdrawalsAmount']),
  availableBalance: jsonAmount(json['availableBalance']),
  jobs: [
    for (final row in jsonRows(json['jobs']))
      if (jsonText(row['id']).isNotEmpty)
        (
          id: jsonText(row['id']),
          taskId: jsonText(row['taskId']),
          title: jsonText(row['title']),
          description: jsonText(row['description']),
          status: jsonText(row['status']),
          statusLabel: jsonText(row['statusLabel']),
          clientName: jsonText(row['clientName']),
          earningAmount: jsonAmount(row['earningAmount']),
          dueAt: jsonDate(row['dueAt']),
        ),
  ],
);

extension OverviewJobText on OverviewJob {
  String get amountLabel => earningAmount == null ? '—' : usd(earningAmount!);

  /// The line under a job title — the status the page itself words, plus the
  /// day the work is due.
  String get milestoneLabel {
    final due = dueAt;
    return due == null ? statusLabel : '$statusLabel · Due ${shortDate(due)}';
  }

  String get shortTitle => title.isEmpty ? 'Project' : title;
}
