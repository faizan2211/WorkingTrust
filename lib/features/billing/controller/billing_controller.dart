import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/network_exceptions.dart';
import '../../../core/utils/link_opener.dart';
import '../../finance/controller/transactions_controller.dart';
import '../../finance/controller/wallet_controller.dart';
import '../../packages/models/package_entry.dart';
import '../models/checkout_entries.dart';
import '../services/billing_service.dart';

/// Where one purchase stands.
enum BillingStatus {
  /// Nothing in flight.
  idle,

  /// Talking to the server — starting Checkout, or asking about a payment.
  working,

  /// The hosted page was handed to the device; the payment happens off-app.
  opened,

  /// The server says the payment has not landed. Asking again is the user's
  /// choice, never a timer.
  pending,

  /// The server says the payment landed and was applied.
  confirmed,

  /// A refusal or a connection problem, with [BillingController.message] as the
  /// wording to show.
  failed,
}

/// Buys a package the way the backend means it to be bought: the app asks for
/// Stripe's hosted page and opens it, then asks the server whether that session
/// was paid.
///
/// Closing the browser proves nothing, so nothing is credited from it. The only
/// answer that changes the account is a 200 from
/// `POST /api/deposits/stripe/confirm`, which is the route that applies the
/// order alongside the webhook — and even then the app mirrors the number the
/// server reported rather than the one it meant to buy.
class BillingController extends ChangeNotifier {
  BillingController._();

  static final BillingController instance = BillingController._();

  static const String _unlisted =
      'This package is not listed for purchase yet.';

  final BillingService _service = BillingService();

  BillingStatus status = BillingStatus.idle;
  String message = '';

  PackageEntry? _package;
  CheckoutSession? _session;

  /// Asks the server for a Checkout page for [package] and hands it to the
  /// browser. [message] holds the refusal when the app never got a page to open.
  Future<void> purchase(PackageEntry package) async {
    if (package.id.isEmpty) {
      _set(BillingStatus.failed, _unlisted);
      return;
    }
    _package = package;
    _session = null;
    _set(BillingStatus.working, '');
    try {
      final session = await _service.startCheckout(package);
      final blocked = await LinkOpener.open(session.checkoutUrl);
      if (blocked != null) {
        _set(BillingStatus.failed, blocked);
        return;
      }
      _session = session;
      _set(
        BillingStatus.opened,
        'Finish the payment in your browser, then come back here.',
      );
    } on NetworkException catch (error) {
      _set(BillingStatus.failed, error.message);
    }
  }

  /// Asks the server once whether the payment landed. There is no automatic
  /// retry and no watching of the browser: this runs when the user says so.
  Future<void> verify() async {
    final session = _session;
    final package = _package;
    if (session == null || package == null) {
      _set(BillingStatus.failed, _unlisted);
      return;
    }
    _set(BillingStatus.working, '');
    try {
      final answer = await _service.confirmCheckout(session.sessionId);
      if (!answer.fulfilled) {
        _set(
          BillingStatus.pending,
          answer.message.isEmpty
              ? 'The payment has not been confirmed yet.'
              : answer.message,
        );
        return;
      }
      // The server applied the fulfilment, so the only figure the app can show
      // is the one its own wallet route reports back.
      _set(BillingStatus.confirmed, _confirmedText(package, answer));
      // The deposit and the connects are the server's rows, so the money
      // screens read them back instead of keeping the checkout's answer.
      unawaited(WalletController.instance.refresh());
      unawaited(TransactionsController.instance.refresh());
    } on NetworkException catch (error) {
      _set(BillingStatus.failed, error.message);
    }
  }

  void reset() {
    _package = null;
    _session = null;
    _set(BillingStatus.idle, '');
  }

  String _confirmedText(PackageEntry package, PaymentConfirmation answer) =>
      package.kind == PackageKind.membership
      ? '${answer.planName.isEmpty ? package.name : answer.planName} is active.'
      : '${answer.connects} Bids added to your account.';

  void _set(BillingStatus next, String text) {
    status = next;
    message = text;
    notifyListeners();
  }
}
