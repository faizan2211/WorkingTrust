import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/network_exceptions.dart';

/// The one thing a device may ask of the account's money: that approved work be
/// paid out.
///
/// The request carries job ids and nothing else. `POST /api/withdrawals` prices
/// each job from its own row, checks it against the stored balance, writes the
/// ledger entry and moves the money — so an amount typed on this device can
/// never become a payout, and a refusal comes back in the route's own words.
class WithdrawalsService {
  WithdrawalsService._();

  static final WithdrawalsService instance = WithdrawalsService._();

  /// The most the route takes in one request, which is its own schema's cap.
  static const int requestMax = 20;

  final ApiClient _apiClient = ApiClient();

  /// Asks for the payout of [assignmentIds] and answers how many rows the
  /// server created. A 400 with no billing method on file, a 409 for a job that
  /// already has a request, a 400 for a balance too small and a 403 for a
  /// suspended account are all raised as a [NetworkException].
  Future<int> request(List<String> assignmentIds) async {
    final response = await _apiClient.post(
      ApiEndpoints.withdrawals,
      body: <String, dynamic>{'assignmentIds': assignmentIds},
    );
    final rows = response is Map<String, dynamic>
        ? response['withdrawals']
        : null;
    if (rows is! List) {
      throw NetworkException('The server did not confirm the withdrawal.');
    }
    return rows.length;
  }
}
