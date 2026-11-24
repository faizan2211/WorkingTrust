/// Backend paths, mirroring the Next.js 15 App Router routes in
/// `src/app/api`. Everything under `/api/auth/` except `register`,
/// `verify-email`, `resend-verification`, `forgot-password`, `verify-otp`,
/// `reset-password` and `mobile-google` is served by the NextAuth catch-all
/// route.
class ApiEndpoints {
  ApiEndpoints._();

  static const String csrf = '/api/auth/csrf';
  static const String credentialsCallback = '/api/auth/callback/credentials';
  static const String session = '/api/auth/session';
  static const String register = '/api/auth/register';
  static const String verifyEmail = '/api/auth/verify-email';
  static const String resendVerification = '/api/auth/resend-verification';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String verifyOtp = '/api/auth/verify-otp';
  static const String resetPassword = '/api/auth/reset-password';

  /// Google sign-in for this app. `POST {idToken}` — the Google ID token the
  /// device obtained natively — and the server answers by setting the same
  /// NextAuth session cookie the website gets. It refuses with 401 for a token
  /// Google did not sign, 403 for a suspended account and 429 for too many
  /// attempts. Only the token goes out; it never comes back.
  static const String mobileGoogle = '/api/auth/mobile-google';

  /// Open projects for the Find Work board. `GET` answers `{tasks: [...]}`,
  /// newest first, and takes two filters: `category` (a slug from
  /// [categories]) and `q`, which the server matches case-insensitively
  /// against the title, description, requirements, deliverables, client name
  /// and category name. There is no pagination, no sort parameter and no
  /// single-task route — the whole board arrives in one response.
  static const String tasks = '/api/tasks';

  /// One category of the board. `GET` answers `{categories: [...]}` with
  /// `{id,name,slug,description}` only — no open-task counts.
  static const String categories = '/api/categories';

  /// Applying on a project. `POST` answers `201 {bid}` after it has spent the
  /// connects, and refuses with 400 for a short proposal, a closed project or a
  /// repeat application, 403 for a suspended account and 400 for too few
  /// connects. There is no route that reads back the bids this account sent.
  static String taskBid(String taskId) => '/api/tasks/$taskId/bid';

  /// The signed-in user's own notifications. `GET` lists them with an unread
  /// count; `PATCH` marks one read, dismisses one, or marks all read. There is
  /// no DELETE — dismissal is a PATCH with `dismiss: true`.
  static const String notifications = '/api/notifications';

  /// The signed-in account's authorized task conversations, newest activity
  /// first. Each row includes the other participant, latest message preview,
  /// and notification-backed unread count.
  static const String conversations = '/api/conversations';

  /// Authenticated registration and deactivation of this device's FCM token.
  static const String fcmToken = '/api/devices/fcm-token';

  /// The signed-in user's own profile. `GET` answers the whole thing in one
  /// response — `{user: {name, title, bio, skills, hourlyRate, avatarUrl,
  /// videoIntroUrl, githubUrl, websiteUrl, youtubeUrl}, languages, education, certifications, employment,
  /// portfolio}` — scoped to the session cookie, with no parameters to pass.
  /// `PATCH` replaces it and always requires a `name`.
  static const String profile = '/api/profile';

  /// `POST` uploads the avatar as a multipart `file` part and answers with the
  /// stored URL; `DELETE` removes it. Never send `avatarUrl` through
  /// [profile]: the backend deletes the previous Cloudinary asset when that
  /// field changes.
  static const String profileAvatar = '/api/profile/avatar';

  /// The five profile sections a device writes one row at a time. Each `POST`
  /// answers `201 {item}` and each row is then addressed by its own id through
  /// [profileEntry]. They have no `GET` of their own — [profile] lists all five
  /// in one response.
  static const String profileLanguages = '/api/profile/languages';
  static const String profileEducation = '/api/profile/education';
  static const String profileCertifications = '/api/profile/certifications';
  static const String profileEmployment = '/api/profile/employment';
  static const String profilePortfolio = '/api/profile/portfolio';

  /// Completed and active assignments for the authenticated profile.
  static const String profileWorkHistory = '/api/profile/work-history';

  /// General attachments for proposals. Accepts images, PDF and Office files
  /// up to 10 MB, returning `{url, filename, size}`.
  static const String upload = '/api/upload';

  /// One row of a section, for `PATCH` and `DELETE`.
  static String profileEntry(String collection, String id) => '$collection/$id';

  /// `POST` takes a multipart `file` of up to 60 MB and answers with the
  /// stored `url` and the `mediaType` the project row should keep.
  static const String profilePortfolioMedia = '/api/profile/portfolio/media';

  /// The intro video, held as one external link on the account: `POST {url}`
  /// answers `{url}`, `DELETE` clears it. There is no upload for it.
  static const String profileVideoIntro = '/api/profile/video-intro';

  /// Two-step verification. `GET` answers the three switches plus `phone`,
  /// `email`, `authenticatorConfigured` and which sign-in providers are linked;
  /// `PATCH` takes exactly the three booleans and answers `{ok:true, …}`.
  static const String accountSecurity = '/api/account/security';

  /// Notification *preferences* — not the list in [notifications]. `GET`
  /// answers `{prefs: {…}}` and `PATCH` takes those six keys verbatim,
  /// answering `{ok:true, prefs: {…}}`.
  static const String accountNotifications = '/api/account/notifications';

  /// `PATCH` only, and it needs a `section`: `"account"` with `name` and
  /// `email`, or `"location"` with `timezone`, `country`, `stateProvince` and
  /// `city`. Both answer `{ok:true, user: {…}, message}`.
  static const String accountContact = '/api/account/contact';

  /// `POST` with `currentPassword`, `newPassword` and `confirmPassword`,
  /// answering `{ok:true}`. There is no read endpoint for a password.
  static const String accountPassword = '/api/account/password';

  /// The authenticator half of two-step verification. `POST` takes no body and
  /// answers `{secret, otpauthUrl}` — the server holds that secret as pending
  /// until `PUT {code}` accepts a code from the app, which is the only thing
  /// that sets `twoStepAuthenticator`. `DELETE` clears the secret and the
  /// switch together. A device shows the secret only for as long as the setup
  /// is open; it is never stored.
  static const String accountSecurityTotp = '/api/account/security/totp';

  /// The SMS half, same shape: `POST` starts it and answers `{ok, channel,
  /// message}` with `channel` of `"sms"` or `"email"` when the provider is
  /// unusable, `PUT {code}` confirms the code that was sent, and `DELETE`
  /// turns the switch off. Nothing readable comes back, and the account needs a
  /// phone number before the route will start at all.
  static const String accountSecuritySms = '/api/account/security/sms';

  /// `DELETE` only, with `{provider: "google" | "apple"}`, answering `{ok:true}`.
  /// There is no route that links a provider — that stays a browser sign-in —
  /// so a device can disconnect one it already reported as linked.
  static const String accountSecurityOauth = '/api/account/security/oauth';

  /// The one saved payment method. `GET` answers `{method, methods}` with at
  /// most a single entry, whose card row carries `cardLast4`, `expMonth` and
  /// `expYear` and never a full number. `POST` replaces it and answers `201
  /// {ok, method, methods}`; `DELETE` clears it back to `{method:null,
  /// methods:[]}`. A card `securityCode` is checked and thrown away, and no
  /// payment is ever taken through here.
  static const String accountBilling = '/api/account/billing';

  /// The saved withdrawal accounts, up to five. `GET` answers `{methods:[…]}`
  /// of `{id, method, label, accountDetails, createdAt}`; `POST {method,
  /// accountDetails, label}` answers `201 {ok, methods}`; `DELETE {id}` removes
  /// one row. These are for listing only — withdrawal processing reads the
  /// separate `billingMethods` column, so saving an account here does not make
  /// it payable.
  static const String accountWithdrawals = '/api/account/withdrawals';

  /// A payout request. `POST {assignmentIds}` — between one and twenty of this
  /// account's own approved jobs — answers `201 {withdrawals}` with one row per
  /// job, and the server sets each amount from the job, decrements the stored
  /// balance and writes the ledger entry. A device never sends an amount. It is
  /// refused with 400 `NO_PAYMENT_METHOD` when no billing method is on file, 409
  /// when that work already has a request, 400 when the balance cannot cover it
  /// and 403 when the account is suspended; 401 without the cookie. Six
  /// requests an hour is all the route allows one account, answering 429 with
  /// the seconds left to wait.
  static const String withdrawals = '/api/withdrawals';

  /// One project's chat thread. `GET` answers the whole thread with the
  /// participant names and the `flagged`/`closed` flags; `POST {body,
  /// attachmentUrl}` answers `201 {message, …}`. It is refused with 403 until
  /// this account has been hired on that project, and a closed thread refuses
  /// new messages. There is no edit, delete, list or read-receipt call, and no
  /// way to discover which task ids exist — a thread is only ever addressed by
  /// The inbox lists authorized task ids through [conversations].
  static String taskChat(String taskId) => '/api/tasks/$taskId/chat';

  /// The signed-in account's wallet, read from the same query the website's
  /// Wallet page runs. `GET` answers `200 {balance, connects, planActive,
  /// pendingDeposit, earningsByJob, transactions, connectsActivity}` — the
  /// stored balance and connects, the newest 30 money rows and 20 connects rows,
  /// the approved jobs that paid out, and the one deposit still `PENDING`. There
  /// are no parameters and nothing is written: reading a wallet cannot change a
  /// balance, a ledger row or a deposit. Refused with 401 without the cookie.
  static const String wallet = '/api/wallet';

  /// The Overview page's four figures and its job list. `GET` answers `200
  /// {workInProgressAmount, inReviewAmount, pendingWithdrawalsAmount,
  /// availableBalance, jobs}` with every assignment still ACTIVE, SUBMITTED or
  /// REJECTED, each carrying its own `status`, the page's `statusLabel`, the
  /// client's name and the due date. No parameters, and no balance is moved by
  /// reading it. Refused with 401 without the cookie.
  static const String reportsOverview = '/api/reports/overview';

  /// The Transactions page's merged money feed. `GET` answers `200 {availableBalance,
  /// pendingEarnings, hasPaymentMethod, rows, clients, total, page, limit,
  /// totalPages}` with `rows` newest first and already paged. Four parameters are
  /// honoured: `page` and `limit` (the server clamps `limit` to its own ceiling),
  /// `type` — one of `all, Client, Withdrawal, Bids, Subscription, Other, Earning`
  /// — and `client`, a name from `clients` or `all`. Anything else for `type` is
  /// a 400 with an `error` and no query. Refused with 401 without the cookie.
  static const String reportsTransactions = '/api/reports/transactions';

  /// My Stats, as the website computes them. `GET` answers `200 {twelveMonthEarnings,
  /// jobSuccessScore, connects, nextMonthConnects, proposalFunnel, profileViews,
  /// impressions, clicks, profileSeries}`. Each chart accepts a required start
  /// date and optional inclusive end date (`proposalStart`, `proposalEnd`,
  /// `profileStart`, `profileEnd`); an omitted end means today. The figures are
  /// the server's — the app never recomputes a funnel or a score. Refused with
  /// 401 without the cookie, and [reportsMyStats] is the only source for these
  /// numbers.
  static const String reportsMyStats = '/api/reports/my-stats';

  /// The weekly report. `GET` answers the freelancer summary `{since, earnings,
  /// projects, proposals, approvedCount, submittedCount, messages}`, or `{since,
  /// clients}` with `?scope=client` — and the client scope needs an active Pro
  /// plan, answering 403 `{error}` without one. Refused with 401 without the
  /// cookie. Nothing is recalculated on the device.
  static const String reportsWeekly = '/api/reports/weekly';

  /// The same report as the text file the website downloads: `GET` answers
  /// `text/plain` with `Content-Disposition: attachment`, and `?scope=client`
  /// gives the client breakdown, which 403s for an account with no Pro plan.
  /// `scope=client` on this route and on [reportsWeekly] mean the same thing.
  static const String reportsWeeklyDownload = '/api/reports/weekly/download';

  /// The proposals this account sent. `GET` answers `200 {proposals, activeWork,
  /// counts, total, page, limit, totalPages}` — `counts` holds the four bid
  /// statuses whatever page is open, `activeWork` is the assignments still ACTIVE
  /// or SUBMITTED, and `proposals` is the paged, newest-first bid list. `status`
  /// narrows it to `PENDING`, `SHORTLISTED`, `AWARDED` or `REJECTED`; anything
  /// else is a 400 with an `error` and no query. `page` and `limit` are clamped
  /// by the server. Refused with 401 without the cookie, and no bid is awarded,
  /// rejected or refunded by reading it.
  static const String bidsMy = '/api/bids/my';

  /// The packages the app sells, read straight from the `Package` table.
  /// `GET ?kind=BIDS` or `?kind=MEMBERSHIP` answers `200 {packages:[…]}` with
  /// the active rows of that kind in the Admin Panel's order (`sortOrder`, then
  /// price), each carrying its real `id`, `name`, `priceUsd`, `connects`,
  /// `description`, `validityDays`, `features`, `audience`, `featured`, `active`
  /// and `serviceFeePct`. Any other `kind` is a 400 with an `error`; nothing
  /// else is ever written. No Stripe configuration crosses the wire.
  static const String packages = '/api/packages';

  /// Starting a Stripe payment for one package. `POST {packageId, purpose,
  /// returnTo}` — `packageId` is the `Package` row's own id, `purpose` is
  /// `"bids"` or `"membership"`, and `returnTo` is the website page Stripe
  /// hands the browser back to. The amount is never sent: the server reads the
  /// price and the connects off its own row and opens a one-off `payment` for a
  /// bid pack or a `subscription` for a plan. Answers
  /// `200 {success, checkoutUrl, sessionId}`. Refusals: 401 with no session,
  /// 400 `"Package is required."` / `"Invalid package."` for a missing, unknown
  /// or deactivated id, 400 `"Invalid membership plan."` or
  /// `"Invalid Buy Bids package."` when the row is of the other kind, and 500
  /// when no Stripe Price ID is configured for it. Only an id [packages] has
  /// listed can be bought, because that is the only route that reveals one.
  static const String stripeCheckout = '/api/deposits/stripe/checkout';

  /// Asking whether one Checkout session has been paid — the only proof of
  /// payment a device can get. `POST {sessionId}` with the id [stripeCheckout]
  /// returned: `200 {ok:true, purpose, planName, connects,
  /// stripeSubscriptionId, alreadyFulfilled}` once Stripe reports the session
  /// paid, which is also when the server applies the connects or the membership
  /// itself; `409 {error, paymentStatus}` while it has not. Anything the device
  /// does after the browser closes is a question, never a credit.
  static const String stripeConfirm = '/api/deposits/stripe/confirm';
}
