import 'json_read.dart';

/// My Stats, exactly as `GET /api/reports/my-stats` computes it.
///
/// None of these numbers is recalculated on the device: the funnel, the Job
/// Success Score, the earnings total and the daily series all come from the
/// route the website uses. `jobSuccessScore` is null when the account has not
/// been hired enough times for a score to exist, which is why it is nullable
/// rather than a zero the account has not earned.
typedef MyStatsSnapshot = ({
  double? twelveMonthEarnings,
  double? jobSuccessScore,
  int? connects,
  int? nextMonthConnects,
  ProposalFunnel funnel,
  int? profileViews,
  int? impressions,
  int? clicks,
  List<StatPoint> profileSeries,
});

typedef ProposalFunnel = ({
  int proposals,
  int viewed,
  int interviews,
  int hires,
});

/// One day of profile activity, in the server's own `label` (`Jan 05`).
typedef StatPoint = ({String label, int? views, int? impressions, int? clicks});

MyStatsSnapshot statsFromJson(Map<String, dynamic> json) {
  final funnel = json['proposalFunnel'];
  final counts = funnel is Map<String, dynamic>
      ? funnel
      : const <String, dynamic>{};
  return (
    twelveMonthEarnings: jsonAmount(json['twelveMonthEarnings']),
    jobSuccessScore: jsonAmount(json['jobSuccessScore']),
    connects: jsonCount(json['connects']),
    nextMonthConnects: jsonCount(json['nextMonthConnects']),
    funnel: (
      proposals: jsonCount(counts['proposals']) ?? 0,
      viewed: jsonCount(counts['viewed']) ?? 0,
      interviews: jsonCount(counts['interviews']) ?? 0,
      hires: jsonCount(counts['hires']) ?? 0,
    ),
    profileViews: jsonCount(json['profileViews']),
    impressions: jsonCount(json['impressions']),
    clicks: jsonCount(json['clicks']),
    profileSeries: [
      for (final row in jsonRows(json['profileSeries']))
        (
          label: jsonText(row['label']),
          views: jsonCount(row['views']),
          impressions: jsonCount(row['impressions']),
          clicks: jsonCount(row['clicks']),
        ),
    ],
  );
}

extension MyStatsText on MyStatsSnapshot {
  String get earningsLabel =>
      twelveMonthEarnings == null ? '—' : usd(twelveMonthEarnings!);

  /// A score the account has not earned yet is shown as such, not as `0%`.
  String get successLabel {
    final score = jobSuccessScore;
    if (score == null) return 'No score yet';
    return '${score == score.roundToDouble() ? score.round() : score}%';
  }

  String get bidBonusLabel {
    final next = nextMonthConnects;
    if (next == null || next <= 0) {
      return 'No connects scheduled for next month';
    }
    return "You've earned $next connects for the next month";
  }

  /// The funnel as the four bars the panel draws, in the server's own order.
  List<({String label, int value})> get funnelBars => [
    (label: 'Proposals sent', value: funnel.proposals),
    (label: 'Were viewed', value: funnel.viewed),
    (label: 'Interviews', value: funnel.interviews),
    (label: 'Hires', value: funnel.hires),
  ];

  List<({String label, int value})> get viewBars => [
    for (final point in profileSeries)
      (label: point.label, value: point.views ?? 0),
  ];

  List<({String label, int value})> get impressionBars => [
    for (final point in profileSeries)
      (label: point.label, value: point.impressions ?? 0),
  ];
}
