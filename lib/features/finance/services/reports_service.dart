import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/network_exceptions.dart';
import '../models/reports_overview.dart';
import '../models/my_stats.dart';
import '../models/transaction_feed.dart';
import '../models/weekly_report.dart';

/// The three report routes the website already runs, plus the My Stats route it
/// was built for.
///
/// Overview, transactions and stats each answer straight from the same builder
/// the corresponding web page uses, so an amount here is the amount the browser
/// shows. The weekly routes are the website's own: the summary needs only a
/// session, the client breakdown needs an active Pro plan, and a 403 from either
/// is passed up as [WeeklyLocked] rather than retried as a failure.
class ReportsService {
  ReportsService._();

  static final ReportsService instance = ReportsService._();

  final ApiClient _apiClient = ApiClient();

  Future<ReportsOverview> fetchOverview() async {
    final response = await _apiClient.get(ApiEndpoints.reportsOverview);
    if (response is! Map<String, dynamic>) {
      throw NetworkException('The server did not return the overview.');
    }
    return overviewFromJson(response);
  }

  /// One page of the merged money feed.
  ///
  /// `type` and `client` are sent as the server expects them so filtering
  /// stays server-side; a `type` the route does not know is refused with a 400
  /// before it queries, which is reported as an ordinary error rather than an
  /// empty list.
  Future<TransactionFeed> fetchTransactions({
    int page = 1,
    int limit = 20,
    TransactionFilter type = TransactionFilter.all,
    String client = 'all',
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.reportsTransactions,
      queryParameters: <String, String>{
        'page': '$page',
        'limit': '$limit',
        'type': type.query,
        'client': client,
      },
    );
    if (response is! Map<String, dynamic>) {
      throw NetworkException('The server did not return any transactions.');
    }
    return transactionsFromJson(response);
  }

  /// My Stats for the two windows the route offers.
  Future<MyStatsSnapshot> fetchStats({
    int proposalDays = 15,
    int profileDays = 7,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.reportsMyStats,
      queryParameters: <String, String>{
        'proposalDays': '$proposalDays',
        'profileDays': '$profileDays',
      },
    );
    if (response is! Map<String, dynamic>) {
      throw NetworkException('The server did not return the statistics.');
    }
    return statsFromJson(response);
  }

  /// The week, as the site computes it.
  ///
  /// `GET /api/reports/weekly` answers `{report: …}` — the one route of these
  /// four that wraps — and the client scope carries only `since` and `clients`
  /// inside it, so the wrapper is unwrapped before the model reads the keys.
  Future<WeeklyReport> fetchWeekly(WeeklyScope scope) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.reportsWeekly,
        queryParameters: scope.query.isEmpty
            ? null
            : <String, String>{'scope': scope.query},
      );
      if (response is! Map<String, dynamic>) {
        throw NetworkException('The server did not return the weekly report.');
      }
      final report = response['report'];
      return weeklyFromJson(report is Map<String, dynamic> ? report : response);
    } on NetworkException catch (e) {
      // The Pro half of the route refuses with 403, which is an upgrade prompt
      // on the card rather than a failure that a retry could fix.
      if (e.statusCode == 403) throw WeeklyLocked(e.message);
      rethrow;
    }
  }

  /// The same report as the text file the website downloads.
  ///
  /// The route answers `text/plain`, so this reads the raw response instead of
  /// asking the JSON helper to decode it. A 403 means the client breakdown is
  /// being asked for without a Pro plan.
  Future<String> fetchWeeklyText(WeeklyScope scope) async {
    final response = await _apiClient.send(
      'GET',
      ApiEndpoints.reportsWeeklyDownload,
      queryParameters: scope.query.isEmpty
          ? null
          : <String, String>{'scope': scope.query},
    );
    if (response.statusCode == 403) {
      throw WeeklyLocked(response.message);
    }
    if (!response.isSuccess) {
      throw NetworkException(response.message, statusCode: response.statusCode);
    }
    if (response.body.isEmpty) {
      throw NetworkException('The server returned an empty report.');
    }
    return response.body;
  }
}

/// The Pro-only half of the weekly report, asked for by an account that does not
/// hold an active Pro plan.
class WeeklyLocked implements Exception {
  final String message;

  WeeklyLocked(this.message);

  @override
  String toString() => message;
}
