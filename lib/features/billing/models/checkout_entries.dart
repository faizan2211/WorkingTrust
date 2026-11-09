/// The answer `POST /api/deposits/stripe/checkout` gives: Stripe's own hosted
/// page, plus the id `POST /api/deposits/stripe/confirm` is asked about.
///
/// No amount is in it. The server priced the order off its own `Package` row,
/// so the app has nothing to add up and nothing to get wrong.
typedef CheckoutSession = ({String checkoutUrl, String sessionId});

/// What the server reported about one Checkout session when asked.
///
/// [fulfilled] is the server's word that Stripe has been paid and the order has
/// been applied — a bid pack's connects or the membership — on the account.
/// [alreadyFulfilled] says it had been applied on an earlier ask, which is how
/// the app avoids counting a purchase twice. [planName] and [connects] are the
/// values on the deposit the server created, and [message] is the wording to
/// show when the payment has not landed.
typedef PaymentConfirmation = ({
  bool fulfilled,
  bool alreadyFulfilled,
  String planName,
  int connects,
  String paymentStatus,
  String message,
});
