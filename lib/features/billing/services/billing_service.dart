import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/network_exceptions.dart';
import '../../packages/models/package_entry.dart';
import '../models/checkout_entries.dart';

/// The two Stripe routes a purchase uses.
///
/// Both are driven by the `Package` id alone: the price, the connects and the
/// Stripe Price ID all live on the server's own row, so nothing here carries an
/// amount.
class BillingService {
  final ApiClient _apiClient = ApiClient();

  /// Opens a Stripe session for [package] — a one-off payment for a bid pack, a
  /// subscription for a plan, which is the server's choice to make.
  ///
  /// Throws [NetworkException] carrying the server's own refusal for a package
  /// it does not have, one it deactivated, one of the other kind, or one with
  /// no Stripe Price configured.
  Future<CheckoutSession> startCheckout(PackageEntry package) async {
    final data = await _apiClient.post(
      ApiEndpoints.stripeCheckout,
      body: {
        'packageId': package.id,
        'purpose': package.kind.purpose,
        'returnTo': package.kind.returnTo,
      },
    );
    final row = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final checkoutUrl = _text(row['checkoutUrl']);
    if (checkoutUrl.isEmpty) {
      throw NetworkException('Stripe did not return a checkout page.');
    }
    return (checkoutUrl: checkoutUrl, sessionId: _text(row['sessionId']));
  }

  /// Asks whether [sessionId] has been paid.
  ///
  /// A 409 here is a normal answer rather than a failure — the payment simply
  /// has not landed yet — so the request goes through [ApiClient.send] and the
  /// status is read from the response instead of being thrown.
  Future<PaymentConfirmation> confirmCheckout(String sessionId) async {
    final response = await _apiClient.send(
      'POST',
      ApiEndpoints.stripeConfirm,
      body: {'sessionId': sessionId},
    );
    final data = response.json ?? const <String, dynamic>{};
    final fulfilled = response.isSuccess && data['ok'] == true;
    return (
      fulfilled: fulfilled,
      alreadyFulfilled: data['alreadyFulfilled'] == true,
      planName: _text(data['planName']),
      connects: _whole(data['connects']),
      paymentStatus: _text(data['paymentStatus']),
      message: fulfilled ? '' : response.message,
    );
  }
}

String _text(Object? value) => value is String ? value.trim() : '';

int _whole(Object? value) => value is num ? value.round() : 0;
