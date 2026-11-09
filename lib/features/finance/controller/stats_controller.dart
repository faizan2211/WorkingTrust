import '../models/my_stats.dart';
import '../services/reports_service.dart';
import 'read_controller.dart';

/// My Stats, from `GET /api/reports/my-stats`.
///
/// The route owns both windows: `proposalDays` and `profileDays` accept 7, 15 or
/// 30 and fall back to their own default for anything else, so the dropdowns
/// only offer those three. Changing one re-reads the route instead of filtering
/// the old answer, because a different window is a different computation.
class StatsController extends ReadController<MyStatsSnapshot> {
  StatsController._();

  static final StatsController instance = StatsController._();

  static const List<int> windows = [7, 15, 30];

  final ReportsService _service = ReportsService.instance;

  int _proposalDays = 15;
  int _profileDays = 7;

  int get proposalDays => _proposalDays;
  int get profileDays => _profileDays;

  Future<void> setProposalDays(int days) async {
    if (days == _proposalDays) return;
    _proposalDays = days;
    await load(force: true);
  }

  Future<void> setProfileDays(int days) async {
    if (days == _profileDays) return;
    _profileDays = days;
    await load(force: true);
  }

  @override
  MyStatsSnapshot emptyValue() => (
    twelveMonthEarnings: null,
    jobSuccessScore: null,
    connects: null,
    nextMonthConnects: null,
    funnel: (proposals: 0, viewed: 0, interviews: 0, hires: 0),
    profileViews: null,
    impressions: null,
    clicks: null,
    profileSeries: const [],
  );

  /// A stats read is never empty: a zero the route returns is the account's
  /// real number, not an absence of data.
  @override
  bool isEmptyValue(MyStatsSnapshot value) => false;

  @override
  Future<MyStatsSnapshot> read() => _service.fetchStats(
    proposalDays: _proposalDays,
    profileDays: _profileDays,
  );
}
