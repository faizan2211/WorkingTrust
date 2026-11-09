import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/network_exceptions.dart';
import '../models/wallet_data.dart';

/// The account's money, read from the route the website's Wallet page backs.
///
/// Nothing here is computed on the device: the balance, the connects count, the
/// payout list and both ledgers are exactly what `GET /api/wallet` reports for
/// the session, which is the same single query the web page runs. The route
/// writes nothing, so this read can never move a balance or duplicate a ledger
/// row.
class WalletService {
  WalletService._();

  static final WalletService instance = WalletService._();

  final ApiClient _apiClient = ApiClient();

  Future<WalletSnapshot> fetch() async {
    final response = await _apiClient.get(ApiEndpoints.wallet);
    if (response is! Map<String, dynamic>) {
      throw NetworkException('The server did not return the wallet.');
    }
    return walletFromJson(response);
  }
}
