import '../models/my_stats.dart';
import '../services/reports_service.dart';
import 'read_controller.dart';

/// My Stats, from `GET /api/reports/my-stats`.
///
/// Each chart is read from the server for its selected calendar-date range.
class StatsController extends ReadController<MyStatsSnapshot> {
  StatsController._();

  static final StatsController instance = StatsController._();

  final ReportsService _service = ReportsService.instance;

  DateTime _proposalStart = _defaultStart(15);
  DateTime? _proposalEnd;
  DateTime _profileStart = _defaultStart(7);
  DateTime? _profileEnd;

  DateTime get proposalStart => _proposalStart;
  DateTime? get proposalEnd => _proposalEnd;
  DateTime get profileStart => _profileStart;
  DateTime? get profileEnd => _profileEnd;
  int get proposalDays =>
      (_proposalEnd ?? _dateOnly(DateTime.now()))
          .difference(_proposalStart)
          .inDays +
      1;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _defaultStart(int days) =>
      _dateOnly(DateTime.now()).subtract(Duration(days: days - 1));

  Future<void> setProposalRange(DateTime start, DateTime? end) async {
    final nextStart = _dateOnly(start);
    final nextEnd = end == null ? null : _dateOnly(end);
    if (nextEnd != null && nextEnd.isBefore(nextStart)) {
      throw ArgumentError('The end date must be on or after the start date.');
    }
    if (nextStart == _proposalStart && nextEnd == _proposalEnd) return;
    _proposalStart = nextStart;
    _proposalEnd = nextEnd;
    await load(force: true);
  }

  Future<void> setProfileRange(DateTime start, DateTime? end) async {
    final nextStart = _dateOnly(start);
    final nextEnd = end == null ? null : _dateOnly(end);
    if (nextEnd != null && nextEnd.isBefore(nextStart)) {
      throw ArgumentError('The end date must be on or after the start date.');
    }
    if (nextStart == _profileStart && nextEnd == _profileEnd) return;
    _profileStart = nextStart;
    _profileEnd = nextEnd;
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
    proposalStart: _proposalStart,
    proposalEnd: _proposalEnd,
    profileStart: _profileStart,
    profileEnd: _profileEnd,
  );
}
