import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/network_exceptions.dart';
import '../models/my_proposals.dart';

/// The proposals this account sent, read from `GET /api/bids/my`.
///
/// The route answers the same two tables the website's panel splits into its
/// tabs, and it does the paging, the status filter and the per-status counts.
/// Nothing here is decided on the device: a bid keeps the status the server
/// stored for it, and reading it cannot award, shortlist, reject or refund it.
class ProposalsService {
  ProposalsService._();

  static final ProposalsService instance = ProposalsService._();

  final ApiClient _apiClient = ApiClient();

  Future<ProposalFeed> fetch({
    int page = 1,
    int limit = 20,
    BidStatus status = BidStatus.all,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.bidsMy,
      queryParameters: <String, String>{
        'page': '$page',
        'limit': '$limit',
        'status': status.query,
      },
    );
    if (response is! Map<String, dynamic>) {
      throw NetworkException('The server did not return any proposals.');
    }
    return proposalsFromJson(response);
  }
}
