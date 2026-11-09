import '../models/reports_overview.dart';
import '../services/reports_service.dart';
import 'read_controller.dart';

/// The Overview figures and job list, from `GET /api/reports/overview`.
class OverviewController extends ReadController<ReportsOverview> {
  OverviewController._();

  static final OverviewController instance = OverviewController._();

  final ReportsService _service = ReportsService.instance;

  @override
  ReportsOverview emptyValue() => (
    workInProgressAmount: null,
    inReviewAmount: null,
    pendingWithdrawalsAmount: null,
    availableBalance: null,
    jobs: const [],
  );

  /// The four amounts are totals the route worked out whether or not it sent
  /// any job rows with them, so an account with nothing in progress still gets
  /// its tiles — showing `$0.00` where the server added up to nothing — and the
  /// screen names the missing list itself.
  @override
  bool isEmptyValue(ReportsOverview value) => false;

  @override
  Future<ReportsOverview> read() => _service.fetchOverview();
}
