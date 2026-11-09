import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:working_trust/core/network/api_client.dart';
import 'package:working_trust/core/network/session_store.dart';
import 'package:working_trust/core/storage/user_data_store.dart';

/// Stands in for the Next.js backend in widget tests: same paths, same field
/// names, same NextAuth cookie and `{url: …}` redirect behaviour as
/// `src/app/api/…`. Everything the app itself does — the CSRF exchange, the
/// form-encoded credentials POST, the cookie jar — still runs for real, so
/// these tests cover the integration instead of faking it away.
class FakeBackend {
  static const String csrfToken = 'fake-csrf-token';
  static const String sessionCookieValue = 'fake-jwt';
  static const String validEmail = 'someone@gmail.com';
  static const String validPassword = 'demo1234';
  static const String unverifiedEmail = 'unverified@gmail.com';
  static const String takenEmail = 'taken@gmail.com';
  static const String validOtp = '123456';
  static const String resetToken = 'fake-reset-token';

  /// The code the fake authenticator route accepts, standing in for the value a
  /// real app derives from the secret it was shown.
  static const String validTotpCode = '654321';

  /// The code the SMS setup route sends. A test can read [smsSetupCode] back, or
  /// overwrite it, to fail the confirmation instead.
  static const String validSmsCode = '246810';

  /// The one Google ID token the mobile route verifies. Any other string fails
  /// the way `verifyIdToken` does, which [googleIdRejected] forces instead.
  static const String validGoogleIdToken = 'fake-google-id-token';

  /// Rows shaped exactly like `Notification` in `prisma/schema.prisma`: no
  /// `isRead` flag, only `readAt` / `dismissedAt` timestamps, plus the web's
  /// own `href` paths.
  static List<Map<String, dynamic>> seedNotifications() {
    final now = DateTime.now().toUtc();
    String iso(Duration age) => now.subtract(age).toIso8601String();
    return [
      {
        'id': 'n1',
        'userId': 'u1',
        'type': 'BID_AWARDED',
        'title': 'Your bid was awarded',
        'body': 'Shopify Store Redesign is yours. Add a milestone to begin.',
        'href': '/my-work/proposals',
        'readAt': null,
        'dismissedAt': null,
        'createdAt': iso(const Duration(seconds: 20)),
      },
      {
        'id': 'n2',
        'userId': 'u1',
        'type': 'CHAT_MESSAGE',
        'title': 'Message from Hana',
        'body': 'Can you share the Figma link before we start?',
        'href': '/messages?task=t9',
        'readAt': null,
        'dismissedAt': null,
        'createdAt': iso(const Duration(minutes: 8)),
      },
      {
        'id': 'n3',
        'userId': 'u1',
        'type': 'WITHDRAWAL_PAID',
        'title': 'Payout on its way',
        'body': 'Rs 12,000 has left for your bank account.',
        'href': '/account/withdrawals',
        'readAt': iso(const Duration(hours: 3)),
        'dismissedAt': null,
        'createdAt': iso(const Duration(hours: 5)),
      },
    ];
  }

  static const List<Map<String, String>> categories = [
    {
      'id': 'c1',
      'name': 'Graphic Design',
      'slug': 'graphic-design',
      'description': 'Logos and brand kits',
    },
    {
      'id': 'c2',
      'name': 'Web Development',
      'slug': 'web-development',
      'description': 'Sites and apps',
    },
    {'id': 'c3', 'name': 'Writing', 'slug': 'writing', 'description': 'Copy'},
  ];

  /// Every request the app made, in order, for assertions about the contract.
  final List<http.Request> requests = [];

  /// The fake `Notification` table. Reseeded by [install] so a PATCH in one
  /// test cannot change what the next one reads.
  final List<Map<String, dynamic>> notifications = [];

  /// Makes the feed answer slowly, so a test can watch overlapping requests.
  bool slowFeed = false;

  /// 500s the way an unhandled throw in the route does: a body that is not
  /// JSON at all.
  bool notificationsBroken = false;

  /// Answers 401 even though the device still holds a cookie, i.e. the session
  /// expired server-side.
  bool sessionRevoked = false;

  /// Refuses the session request the way a device with no network does, so the
  /// profile is left holding a cookie it cannot read.
  bool sessionBroken = false;

  /// 401s the mobile Google route, i.e. the ID token fails verification, so no
  /// cookie is ever set.
  bool googleIdRejected = false;

  /// 403s the mobile Google route the way a `SUSPENDED` user row does.
  bool googleAccountSuspended = false;

  /// The `User.id` the session answers with. Changing it between two sign-ins
  /// is how a test puts a second account on the same device.
  String sessionId = 'u1';

  /// The `image` the session carries. A credentials sign-in never produces one,
  /// so this stays null unless a test wants to hand the device a photo.
  String? sessionImage;

  /// The avatar the fake account stores, so a profile write and the next
  /// session read agree, the way the backend's `avatarUrl` column does.
  String? storedAvatarUrl;

  /// The `videoIntroUrl` column, kept by the video-intro route alone.
  String? storedVideoIntro;

  /// The other `User` columns `PATCH /api/profile` writes and `GET /api/profile`
  /// reads back, in the route's own replace semantics: a field the body leaves
  /// out is stored as null.
  String? storedTitle;
  String? storedBio;
  String? storedSkills;
  double? storedHourlyRate;

  /// The columns the Settings profile tab writes through the same route. The
  /// route nulls `workGoal` for a body that leaves it out but hands
  /// `experienceLevel` as `undefined`, which Prisma reads as "keep the column",
  /// and the five settings columns are only written when the body carries the
  /// key at all — so the fake has to keep those three behaviours apart.
  String? storedWorkGoal;
  String? storedExperienceLevel;
  String? storedVisibility;
  String? storedEarningPrivacy;
  String? storedGithubUrl;
  String? storedWebsiteUrl;
  String? storedYoutubeUrl;
  List<String>? storedInterestSlugs;

  /// Fails the profile read the way a device with no network does, while the
  /// session itself stays readable.
  bool profileReadBroken = false;

  /// Answers the profile read with a body that has no `user` in it, the way a
  /// proxy error page or a half-written response does.
  bool profileReadMalformed = false;

  /// Holds a profile read open, so a test can move the account on while it is
  /// still outstanding.
  bool slowProfileRead = false;

  /// The account the `stored…` profile columns above belong to. The fake holds
  /// one `User` row, so a read for a different account must answer with nothing
  /// rather than hand over what another account saved.
  String profileOwner = '';

  /// The fake rows of the five profile section tables, keyed by collection.
  /// Each row keeps the `userId` that wrote it, and `GET /api/profile` lists
  /// only the ones belonging to the account the session answers for.
  final Map<String, List<Map<String, dynamic>>> sectionRows = {};

  /// The fake `Task` columns `GET /api/tasks/[id]/chat` reads, keyed by id, with
  /// the one `TaskAssignment` that unlocks a thread folded in as `hired`.
  final Map<String, Map<String, dynamic>> chatTasks = {};

  /// The rows returned by the account-scoped `GET /api/conversations` inbox.
  final List<Map<String, dynamic>> conversationRows = [];
  bool conversationsBroken = false;

  /// The fake `ChatMessage` table, per task, in the database's own oldest-first
  /// order. Rows keep the sender's name and role so the route can label them.
  final Map<String, List<Map<String, dynamic>>> chatRows = {};

  /// The `User.status` a send reads before it will store anything.
  bool accountSuspended = false;

  /// The fake `Task` table, in the columns `findWorkTasks` selects. `status`,
  /// `categorySlug` and `deadlineHours` stay inside the fake: the route filters
  /// on them but the web's select does not send all of them.
  final List<Map<String, dynamic>> tasks = [];

  /// The fake `Bid` table, which the bid route writes and never reads back.
  final List<Map<String, dynamic>> bids = [];

  /// The `User.connects` column. Only the bid route spends it, and no route
  /// returns it, so the app can never show this number.
  int storedConnects = 134;

  /// The `User.walletBalance` column, which the wallet, overview and
  /// transaction routes all report as the account's money. Null when the
  /// column has nothing in it, which is what the screens show as `—`.
  double? storedBalance = 1240.50;

  /// The fake `TaskAssignment` table. Its `status` decides the Overview page's
  /// three money groups and the wallet's paid-out jobs, exactly as the web's
  /// `status: "ACTIVE" | "SUBMITTED" | "REJECTED" | "APPROVED"` filters do.
  final List<Map<String, dynamic>> assignments = [];

  /// The fake `WalletTransaction` rows — the ledger the Wallet screen lists and
  /// the Transactions page folds into its merged feed (and skips where an
  /// earning or withdrawal row already reports the same money).
  final List<Map<String, dynamic>> walletTxs = [];

  /// The fake `ConnectLedger` rows: one entry per connects change.
  final List<Map<String, dynamic>> connectLedger = [];

  /// The fake `Withdrawal` rows, keyed to an assignment by `assignmentId` the
  /// way the web's `assignment.withdrawal` relation is.
  final List<Map<String, dynamic>> withdrawals = [];

  /// The `ProfileAnalyticsEvent` rows My Stats buckets into its daily series.
  final List<Map<String, dynamic>> profileEvents = [];

  /// The row `activeMembership` answers with — `{'planName': 'Pro',
  /// 'monthlyConnects': 120}` — or null for an account with no plan. The
  /// plan name is what decides the weekly client report's 403.
  Map<String, dynamic>? membership;

  /// 500s the five finance reads the way an unhandled Prisma throw does.
  bool financeBroken = false;

  /// Holds a finance read open, so a test can watch a second pull while the
  /// first is still outstanding.
  bool slowFinance = false;

  /// The fake `Package` table, in that table's own column names, with `features`
  /// stored as the JSON string the text column holds. `/api/packages` serves
  /// these rows out, so a test that wants a pack on a screen files it here.
  final List<Map<String, dynamic>> packages = [];

  /// The fake `Deposit` rows the checkout route creates, keyed by the Stripe
  /// session id the app is handed back.
  final Map<String, Map<String, dynamic>> deposits = {};

  /// Leaves every deposit unpaid, the way a Checkout page the buyer never
  /// finishes does: the confirm route keeps answering 409.
  bool paymentUnpaid = false;

  /// 500s the package list the way an unhandled Prisma throw does.
  bool packagesBroken = false;

  /// Holds the package list open, so a test can see the screen while it waits.
  bool slowPackages = false;

  /// 500s the board the way an unhandled throw in the route does.
  bool tasksBroken = false;

  /// Holds a board read open, so a test can watch overlapping requests.
  bool slowTasks = false;

  int _bidSequence = 0;

  /// Numbers the fake `Deposit` rows and their Stripe session ids, so two
  /// purchases in one test never share a session.
  int _depositSequence = 0;

  /// 500s a thread the way an unhandled throw in the chat route does.
  bool chatBroken = false;

  /// Holds a send open, so a test can watch what a second tap does while the
  /// first is still outstanding.
  bool slowChat = false;

  /// The `User.role` the session carries, which decides both chat access and
  /// the sender labels the route writes.
  String sessionRole = 'FREELANCER';

  int _rowSequence = 0;
  int _chatSequence = 0;

  /// The `User` columns `GET /api/account/security` reads, in the backend's own
  /// words. `totpSecret` and the two provider ids decide the reported flags, so
  /// a test can make the route refuse an authenticator switch the way the real
  /// one does.
  final Map<String, dynamic> security = _initialSecurity();

  static Map<String, dynamic> _initialSecurity() => {
    'twoStepMobileApp': false,
    'twoStepSms': false,
    'twoStepAuthenticator': false,
    'totpSecret': null,
    'phone': null,
    'googleId': null,
    'appleId': null,
  };

  /// The `notificationPrefs` column, kept as the JSON string the route writes.
  String? prefsColumn;

  /// The authenticator secret `POST /api/account/security/totp` puts on the
  /// account before any code proves the app can read it. The route stores it
  /// with a `pending:` prefix and leaves the switch off, and only its `PUT`
  /// promotes it.
  String? pendingTotpSecret;

  /// The code the SMS setup route sends to the phone. The device never receives
  /// it, so a test reads it here — or overwrites it to fail the confirmation.
  String? smsSetupCode;

  /// Stands in for a deployment with no Twilio: the route then puts the code in
  /// an email and says which way it went.
  bool smsDeliveryFails = false;

  /// The fake `billingMethods` rows. One column holds them, and the route keeps
  /// at most one, so a second save replaces the first.
  final List<Map<String, dynamic>> billingMethods = [];

  /// The fake `withdrawalMethods` rows, which the same route logic caps at five.
  final List<Map<String, dynamic>> withdrawalMethods = [];

  /// Numbers the `bm_…` / `wm_…` ids so two saves in one test never collide.
  int _methodSequence = 0;

  /// Numbers the `nw…` rows a payout request writes, kept apart from the seeded
  /// `w1` / `w2` ids for the same reason.
  int _withdrawalSequence = 0;

  /// When this account last asked for a payout. The route serves six an hour
  /// and answers 429 with the seconds left, so the fake keeps the same window.
  final List<DateTime> _withdrawTimes = [];

  /// The account's password, held as plain text because the fake compares
  /// rather than hashes.
  String storedPassword = validPassword;

  /// The `name` the contact route writes for the account section.
  String storedName = 'Someone';

  /// The four location columns the contact route writes. No read route exists
  /// for them, so a GET never shows these values.
  final Map<String, String> storedLocation = {};

  /// The last body sent to `PATCH /api/profile`.
  Map<String, dynamic>? profileUpdate;

  /// Set once the credentials callback is satisfied, mimicking a browser that
  /// now carries a session cookie.
  bool _sessionIssued = false;

  /// One `ChatMessage` row as the database holds it: the sender is a nested
  /// `User` with only id, name and role selected.
  static Map<String, dynamic> chatRow(
    String body, {
    String senderId = 'u1',
    String senderName = 'Someone',
    String senderRole = 'FREELANCER',
    String? file,
    Duration ago = const Duration(minutes: 1),
  }) {
    return {
      'senderId': senderId,
      'sender': {'id': senderId, 'name': senderName, 'role': senderRole},
      'body': body,
      'attachmentUrl': file,
      'createdAt': DateTime.now().toUtc().subtract(ago),
    };
  }

  /// Puts one project's thread where `GET/POST /api/tasks/[id]/chat` reads it:
  /// the `Task` columns, the `TaskAssignment` that unlocks the conversation
  /// (or [hired] false, which is the only way the route answers 403), and the
  /// messages oldest first.
  void seedChat(
    String taskId, {
    String clientName = 'Hana',
    String? clientAvatarUrl,
    String title = 'Shopify Store Redesign',
    String freelancerName = 'Someone',
    String? freelancerAvatarUrl,
    bool flagged = false,
    bool closed = false,
    bool hired = true,
    List<Map<String, dynamic>>? messages,
  }) {
    chatTasks[taskId] = {
      'clientName': clientName,
      'clientAvatarUrl': clientAvatarUrl,
      'title': title,
      'chatFlagged': flagged,
      'chatClosed': closed,
      'freelancerName': freelancerName,
      'freelancerAvatarUrl': freelancerAvatarUrl,
      'hired': hired,
    };
    chatRows[taskId] = [
      for (final row
          in messages ??
              [
                chatRow(
                  'Can you share the Figma link before we start?',
                  senderId: 'admin1',
                  senderName: clientName,
                  senderRole: 'ADMIN',
                  ago: const Duration(minutes: 8),
                ),
                chatRow(
                  'Yes — sending it now.',
                  ago: const Duration(minutes: 6),
                ),
              ])
        Map<String, dynamic>.from(row)..['id'] = 'm${++_chatSequence}',
    ];
  }

  /// Puts one open project in the fake `Task` table, in the columns
  /// `findWorkTasks` selects. Everything the board does not send is left out
  /// rather than invented: there is no `requirements` or `deliverables` in the
  /// response, even though `q` searches those columns.
  void seedTask(
    String id, {
    String title = 'Shopify Store Redesign',
    String description = 'Finish the remaining setup on a live Shopify store.',
    String categoryName = 'E-Commerce',
    String categorySlug = 'ecommerce',
    String difficulty = 'MEDIUM',
    double earningAmount = 230,
    int connectsCost = 40,
    int submittedProposals = 12,
    String clientName = 'Hana',
    String? clientCountry = 'Pakistan',
    double? clientRating = 4.6,
    double? clientTotalSpent = 200000,
    bool paymentVerified = true,
    int? deadlineValue = 2,
    String deadlineUnit = 'DAYS',
    int deadlineHours = 72,
    String status = 'OPEN',
    Duration ago = const Duration(minutes: 10),
  }) {
    tasks.add({
      'id': id,
      'title': title,
      'description': description,
      'createdAt': DateTime.now().toUtc().subtract(ago).toIso8601String(),
      'difficulty': difficulty,
      'deadlineValue': deadlineValue,
      'deadlineUnit': deadlineUnit,
      'deadlineHours': deadlineHours,
      'connectsCost': connectsCost,
      'submittedProposals': submittedProposals,
      'earningAmount': earningAmount,
      'clientName': clientName,
      'clientAvatarUrl': null,
      'clientCountry': clientCountry,
      'clientRating': clientRating,
      'clientTotalSpent': clientTotalSpent,
      'paymentVerified': paymentVerified,
      'categoryName': categoryName,
      'categorySlug': categorySlug,
      'status': status,
    });
  }

  /// The projects the Find Work tests read. They are separated in time so the
  /// server's newest-first order is visible in the list.
  void seedTasks() {
    seedTask('t1', title: 'Shopify Store Redesign');
    seedTask(
      't2',
      title: 'Real Estate Market Data Analyst & Dashboard Developer',
      description: 'Clean county sale records and put a filterable dashboard behind them.',
      categoryName: 'Data Analytics',
      categorySlug: 'data-analytics',
      difficulty: 'SMALL',
      earningAmount: 950,
      connectsCost: 25,
      submittedProposals: 4,
      clientName: 'Bessie',
      clientRating: null,
      clientTotalSpent: null,
      paymentVerified: false,
      deadlineValue: null,
      deadlineUnit: 'HOURS',
      deadlineHours: 72,
      ago: const Duration(hours: 1),
    );
    seedTask(
      't3',
      title: 'Mobile App UI Design in Figma for a Delivery Service',
      description:
          'Twenty delivery screens with a component library to hand off.',
      categoryName: 'Graphic Design',
      categorySlug: 'graphic-design',
      difficulty: 'LARGE',
      earningAmount: 480,
      connectsCost: 60,
      submittedProposals: 8,
      clientName: 'Courtney',
      clientCountry: 'United Kingdom',
      clientRating: 4,
      clientTotalSpent: 45000,
      deadlineValue: 3,
      deadlineUnit: 'WEEKS',
      ago: const Duration(days: 2),
    );
    seedTask(
      't4',
      title: 'Landing Page Copywriting for a Fintech Startup',
      description:
          'Headline, section copy and call-to-action variants for one page.',
      categoryName: 'Writing',
      categorySlug: 'writing',
      difficulty: 'SMALL',
      earningAmount: 120,
      connectsCost: 15,
      submittedProposals: 21,
      clientName: 'Amara',
      clientCountry: 'Nigeria',
      clientRating: 5,
      clientTotalSpent: 12000,
      deadlineValue: 6,
      deadlineUnit: 'HOURS',
      ago: const Duration(hours: 5),
    );
  }

  /// The jobs, ledgers and profile events the five finance read routes serve.
  /// They are filed against the four seeded projects, so a title or an amount
  /// in a response is the same one `/api/tasks` reports.
  ///
  /// The sums a test can predict from these rows: `$1,180` of approved work in
  /// the last twelve months, `$230` in progress, `$480` in review, `$400` of
  /// pending withdrawals, a `$880` pending figure on the Transactions page and a
  /// success score of 2 approved out of 3 decided jobs.
  void seedFinance() {
    final now = DateTime.now().toUtc();
    String iso(Duration age) => now.subtract(age).toIso8601String();
    storedBalance = 1240.50;
    membership = null;
    assignments
      ..clear()
      ..addAll([
        {
          'id': 'a1',
          'userId': sessionId,
          'taskId': 't1',
          'bidId': null,
          'status': 'ACTIVE',
          'payoutAmount': null,
          'dueAt': iso(const Duration(days: -4)),
          'createdAt': iso(const Duration(days: 9)),
          'updatedAt': iso(const Duration(hours: 6)),
        },
        {
          'id': 'a2',
          'userId': sessionId,
          'taskId': 't3',
          'bidId': null,
          'status': 'SUBMITTED',
          'payoutAmount': 480.0,
          'dueAt': iso(const Duration(days: -1)),
          'createdAt': iso(const Duration(days: 12)),
          'updatedAt': iso(const Duration(hours: 2)),
        },
        {
          'id': 'a3',
          'userId': sessionId,
          'taskId': 't4',
          'bidId': null,
          'status': 'REJECTED',
          'payoutAmount': null,
          'dueAt': iso(const Duration(days: -2)),
          'createdAt': iso(const Duration(days: 6)),
          'updatedAt': iso(const Duration(days: 1)),
        },
        {
          'id': 'a4',
          'userId': sessionId,
          'taskId': 't2',
          'bidId': null,
          'status': 'APPROVED',
          'payoutAmount': 950.0,
          'dueAt': iso(const Duration(days: 20)),
          'createdAt': iso(const Duration(days: 30)),
          'updatedAt': iso(const Duration(days: 3)),
        },
        {
          'id': 'a5',
          'userId': sessionId,
          'taskId': 't1',
          'bidId': null,
          'status': 'APPROVED',
          'payoutAmount': null,
          'dueAt': iso(const Duration(days: 40)),
          'createdAt': iso(const Duration(days: 55)),
          'updatedAt': iso(const Duration(days: 40)),
        },
      ]);
    walletTxs
      ..clear()
      ..addAll([
        {
          'id': 'tx1',
          'userId': sessionId,
          'type': 'CREDIT',
          'amount': 950.0,
          'reason': 'Task approved: ${tasks[1]['title']}',
          'refId': 'a4',
          'createdAt': iso(const Duration(days: 3)),
        },
        {
          'id': 'tx2',
          'userId': sessionId,
          'type': 'DEBIT',
          'amount': -400.0,
          'reason': 'Withdrawal request for ${tasks[1]['title']}',
          'refId': 'w1',
          'createdAt': iso(const Duration(hours: 1)),
        },
        {
          'id': 'tx3',
          'userId': sessionId,
          'type': 'CREDIT',
          'amount': 120.0,
          'reason': 'Referral bonus',
          'refId': null,
          'createdAt': iso(const Duration(days: 7)),
        },
        {
          'id': 'tx4',
          'userId': sessionId,
          'type': 'DEBIT',
          'amount': -35.0,
          'reason': 'Manual adjustment',
          'refId': null,
          'createdAt': iso(const Duration(days: 15)),
        },
      ]);
    connectLedger
      ..clear()
      ..addAll([
        {
          'id': 'cl1',
          'userId': sessionId,
          'delta': -40,
          'reason': 'Bid on ${tasks[0]['title']}',
          'refId': 't1',
          'createdAt': iso(const Duration(hours: 5)),
        },
        {
          'id': 'cl2',
          'userId': sessionId,
          'delta': 60,
          'reason': 'Bids package purchase',
          'refId': null,
          'createdAt': iso(const Duration(days: 2)),
        },
      ]);
    withdrawals
      ..clear()
      ..addAll([
        {
          'id': 'w1',
          'userId': sessionId,
          'assignmentId': 'a4',
          'amount': 400.0,
          'status': 'PENDING',
          'method': 'Bank transfer',
          'projectTitle': tasks[1]['title'],
          'clientName': tasks[1]['clientName'],
          'createdAt': iso(const Duration(hours: 1)),
        },
        {
          'id': 'w2',
          'userId': sessionId,
          'assignmentId': 'a5',
          'amount': 250.0,
          'status': 'PAID',
          'method': 'JazzCash',
          'projectTitle': tasks[0]['title'],
          'clientName': tasks[0]['clientName'],
          'createdAt': iso(const Duration(days: 20)),
        },
      ]);
    profileEvents
      ..clear()
      ..addAll([
        for (final age in [
          const Duration(hours: 3),
          const Duration(hours: 9),
          const Duration(days: 1, hours: 4),
        ])
          {'userId': sessionId, 'kind': 'VIEW', 'createdAt': iso(age)},
        for (final age in [
          const Duration(hours: 2),
          const Duration(hours: 5),
          const Duration(days: 2),
          const Duration(days: 2),
          const Duration(days: 3),
        ])
          {'userId': sessionId, 'kind': 'IMPRESSION', 'createdAt': iso(age)},
        for (final age in [const Duration(hours: 4), const Duration(days: 1)])
          {'userId': sessionId, 'kind': 'CLICK', 'createdAt': iso(age)},
        // Outside every window the route offers, so a series test can see the
        // range really is applied.
        {
          'userId': sessionId,
          'kind': 'VIEW',
          'createdAt': iso(const Duration(days: 12)),
        },
      ]);
  }

  /// Files a bid history — one project per status the Proposals page counts —
  /// without touching the four open board rows or the empty `bids` table a
  /// submit test starts from. `/api/bids/my` and My Stats' funnel read these.
  void seedProposalHistory() {
    final now = DateTime.now().toUtc();
    String iso(Duration age) => now.subtract(age).toIso8601String();
    seedTask(
      't5',
      title: 'Podcast Intro Jingle Package',
      categoryName: 'Audio',
      categorySlug: 'audio',
      earningAmount: 180,
      clientName: 'Nadia',
      status: 'CLOSED',
      ago: const Duration(days: 8),
    );
    seedTask(
      't6',
      title: 'CRM Data Import Cleanup',
      categoryName: 'Data Analytics',
      categorySlug: 'data-analytics',
      earningAmount: 260,
      clientName: 'Bessie',
      status: 'CLOSED',
      ago: const Duration(days: 12),
    );
    seedTask(
      't7',
      title: 'Brand Guidelines Document',
      categoryName: 'Graphic Design',
      categorySlug: 'graphic-design',
      earningAmount: 300,
      clientName: 'Courtney',
      status: 'CLOSED',
      ago: const Duration(days: 20),
    );
    bids
      ..clear()
      ..addAll([
        {
          'id': 'pb1',
          'userId': sessionId,
          'taskId': 't1',
          'proposal':
              'I have shipped three Shopify themes and can finish the setup.',
          'bidAmount': null,
          'extraConnects': 0,
          'connectsSpent': 40,
          'status': 'PENDING',
          'createdAt': iso(const Duration(days: 1)),
        },
        {
          'id': 'pb2',
          'userId': sessionId,
          'taskId': 't5',
          'proposal': 'Two minute jingle, three revisions included.',
          'bidAmount': 180,
          'extraConnects': 0,
          'connectsSpent': 15,
          'status': 'SHORTLISTED',
          'createdAt': iso(const Duration(days: 5)),
        },
        {
          'id': 'pb3',
          'userId': sessionId,
          'taskId': 't6',
          'proposal': 'I clean imported CRM rows with a scripted pass.',
          'bidAmount': null,
          'extraConnects': 0,
          'connectsSpent': 25,
          'status': 'AWARDED',
          'createdAt': iso(const Duration(days: 9)),
        },
        {
          'id': 'pb4',
          'userId': sessionId,
          'taskId': 't7',
          'proposal': 'A written guideline system, not just a PDF.',
          'bidAmount': 300,
          'extraConnects': 0,
          'connectsSpent': 60,
          'status': 'REJECTED',
          'createdAt': iso(const Duration(days: 16)),
        },
      ]);
    // The awarded bid became a live assignment, which is how the web's Active
    // tab shows work the app can also reach through `/api/bids/my`.
    assignments.add({
      'id': 'a6',
      'userId': sessionId,
      'taskId': 't6',
      'bidId': 'pb3',
      'status': 'ACTIVE',
      'payoutAmount': null,
      'dueAt': iso(const Duration(days: -3)),
      'createdAt': iso(const Duration(days: 8)),
      'updatedAt': iso(const Duration(hours: 12)),
    });
  }

  /// Files [rows] in the fake table of one profile section, under the account
  /// the session answers for, as if the website had saved them. Each row is
  /// written in that table's own column names.
  void seedSection(String collection, List<Map<String, dynamic>> rows) {
    sectionRows[collection] = [
      for (final row in rows) {'userId': sessionId, ...row},
    ];
  }

  http.Client get client => MockClient(_handle);
  List<String> get paths => requests.map((r) => r.url.path).toList();

  int countOf(String path) => requests.where((r) => r.url.path == path).length;

  /// Pretends a previous run signed in: the backend would hand the device a
  /// session cookie, and the app's stored copy of it is what decides whether a
  /// reopen is authenticated.
  void issueSessionCookie() {
    _sessionIssued = true;
    SessionStore.instance.absorb([
      'next-auth.session-token=$sessionCookieValue; Path=/; HttpOnly',
    ]);
  }

  /// Maps [path] to the decoded body of the last request that hit it.
  Map<String, dynamic> bodyFor(String path) {
    final request = requests.lastWhere((r) => r.url.path == path);
    final text = request.body;
    if (request.headers['content-type']?.contains('form-urlencoded') ?? false) {
      return Map<String, dynamic>.from(Uri.splitQueryString(text));
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Future<void> install() async {
    requests.clear();
    _sessionIssued = false;
    slowFeed = false;
    notificationsBroken = false;
    sessionBroken = false;
    sessionRevoked = false;
    googleIdRejected = false;
    googleAccountSuspended = false;
    sessionId = 'u1';
    sessionImage = null;
    profileUpdate = null;
    storedAvatarUrl = null;
    storedVideoIntro = null;
    storedTitle = null;
    storedBio = null;
    storedSkills = null;
    storedHourlyRate = null;
    storedWorkGoal = null;
    storedExperienceLevel = null;
    storedVisibility = null;
    storedEarningPrivacy = null;
    storedGithubUrl = null;
    storedWebsiteUrl = null;
    storedYoutubeUrl = null;
    storedInterestSlugs = null;
    profileReadBroken = false;
    profileReadMalformed = false;
    slowProfileRead = false;
    profileOwner = '';
    _rowSequence = 0;
    sectionRows.clear();
    security
      ..clear()
      ..addAll(_initialSecurity());
    prefsColumn = null;
    pendingTotpSecret = null;
    smsSetupCode = null;
    smsDeliveryFails = false;
    billingMethods.clear();
    withdrawalMethods.clear();
    _methodSequence = 0;
    _withdrawalSequence = 0;
    _withdrawTimes.clear();
    storedPassword = validPassword;
    storedName = 'Someone';
    storedLocation.clear();
    accountSuspended = false;
    chatBroken = false;
    slowChat = false;
    tasksBroken = false;
    slowTasks = false;
    storedConnects = 134;
    financeBroken = false;
    slowFinance = false;
    packages.clear();
    deposits.clear();
    _depositSequence = 0;
    paymentUnpaid = false;
    packagesBroken = false;
    slowPackages = false;
    _bidSequence = 0;
    bids.clear();
    tasks.clear();
    seedTasks();
    seedFinance();
    sessionRole = 'FREELANCER';
    _chatSequence = 0;
    chatTasks.clear();
    chatRows.clear();
    conversationRows
      ..clear()
      ..add({
        'taskId': 't9',
        'projectTitle': 'Shopify Store Redesign',
        'name': 'Hana',
        'avatarUrl': null,
        'preview': 'Can you share the Figma link before we start?',
        'lastMessageAt': DateTime.now().toUtc().toIso8601String(),
        'unreadCount': 1,
        'flagged': false,
        'closed': false,
      });
    conversationsBroken = false;
    // The project the seeded `CHAT_MESSAGE` row names, so the Messages list has
    // a thread the app can honestly open.
    seedChat('t9');
    notifications
      ..clear()
      ..addAll([
        for (final row in seedNotifications()) Map<String, dynamic>.from(row),
      ]);
    // The real jar persists through a platform channel, which a widget test's
    // fake clock can never resolve.
    SessionStore.instance.useInMemoryStorage();
    await SessionStore.instance.clear();
    UserDataStore.instance.useInMemoryStorage();
    ApiClient().useClient(client);
  }

  bool _hasSession(http.Request request) =>
      _sessionIssued &&
      (request.headers['cookie']?.contains('next-auth.session-token') ?? false);

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    final method = request.method;

    if (path == '/api/categories' && method == 'GET') {
      return _json(200, {'categories': categories});
    }

    // Mirrors src/app/api/packages/route.ts: the active rows of the asked kind,
    // in the Admin Panel's order, with a 400 for a kind the table does not use.
    if (path == '/api/packages' && method == 'GET') {
      return _packageList(request);
    }

    if (path == '/api/deposits/stripe/checkout' && method == 'POST') {
      return _stripeCheckout(request);
    }

    if (path == '/api/deposits/stripe/confirm' && method == 'POST') {
      return _stripeConfirm(request);
    }

    // Mirrors src/app/api/tasks/route.ts: public, OPEN only, filtered by the
    // `category` slug and the `q` word, newest first, and no pagination.
    if (path == '/api/tasks' && method == 'GET') {
      if (slowTasks) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      if (tasksBroken) return _json(500, 'Internal Server Error');
      final params = request.url.queryParameters;
      final slug = params['category'];
      final word = params['q']?.trim().toLowerCase();
      final visible = tasks.where((row) {
        if (row['status'] != 'OPEN') return false;
        if (slug != null && slug.isNotEmpty && row['categorySlug'] != slug) {
          return false;
        }
        if (word == null || word.isEmpty) return true;
        // `buildFindWorkWhere`'s OR list, on the columns the fake table holds.
        return [
          row['title'],
          row['description'],
          row['clientName'],
          row['categoryName'],
        ].any((value) => '${value ?? ''}'.toLowerCase().contains(word));
      }).toList()..sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
      return _json(200, {
        'tasks': [for (final row in visible) _taskRow(row)],
      });
    }

    // Mirrors src/app/api/tasks/[id]/bid/route.ts, in its own order: session,
    // `bidSchema`, the project, a repeat application, suspension, connects.
    final bid = _bidRoute.firstMatch(path);
    if (bid != null) return _taskBid(request, bid.group(1)!);

    // The five read routes the Wallet, Reports, Transactions, My Stats, My
    // Proposals and My Reports screens share. Each mirrors its own
    // `src/app/api/…` route and the builder behind it — same session gate, same
    // parameter rules, same merged feed and the same exclusions — so a number a
    // test reads here is the number the web page shows.
    if (path == '/api/wallet' && method == 'GET') {
      return _await(_wallet(request));
    }
    if (path == '/api/reports/overview' && method == 'GET') {
      return _await(_reportOverview(request));
    }
    if (path == '/api/reports/transactions' && method == 'GET') {
      return _await(_transactions(request));
    }
    if (path == '/api/reports/my-stats' && method == 'GET') {
      return _await(_myStats(request));
    }
    if (path == '/api/reports/weekly' && method == 'GET') {
      return _await(_weekly(request));
    }
    if (path == '/api/reports/weekly/download' && method == 'GET') {
      return _await(_weeklyDownload(request));
    }
    if (path == '/api/bids/my' && method == 'GET') {
      return _await(_myProposals(request));
    }

    // Mirrors src/app/api/withdrawals/route.ts and the `requestWorkWithdrawals`
    // transaction behind it: the only fake route that moves the wallet balance.
    // A device names approved jobs, never an amount.
    if (path == '/api/withdrawals' && method == 'POST') {
      return _await(_requestWithdrawal(request));
    }

    // Mirrors src/app/api/notifications/route.ts: 401 without the session
    // cookie, dismissed rows hidden, newest first, unread counted server-side.
    if (path == '/api/notifications' && method == 'GET') {
      if (slowFeed) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      if (notificationsBroken) return _json(500, 'Internal Server Error');
      final visible = notifications
          .where((row) => row['dismissedAt'] == null)
          .toList();
      final unread = visible.where((row) => row['readAt'] == null).length;
      return _json(200, {'notifications': visible, 'unread': unread});
    }

    if (path == '/api/conversations' && method == 'GET') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      if (conversationsBroken) {
        return _json(500, {'error': 'Unable to load conversations.'});
      }
      return _json(200, {'conversations': conversationRows});
    }

    if (path == '/api/notifications' && method == 'PATCH') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      if (notificationsBroken) return _json(500, 'Internal Server Error');
      final body = bodyFor(path);
      final now = DateTime.now().toUtc().toIso8601String();
      if (body['all'] == true) {
        for (final row in notifications) {
          if (row['readAt'] == null) row['readAt'] = now;
        }
        return _json(200, {'ok': true});
      }
      final id = body['id'];
      if (body['id'] is! String) {
        final taskId = body['taskId'];
        if (taskId is! String) return _json(400, {'error': 'Missing id'});
        // The chat-read branch: only the `CHAT_MESSAGE` rows whose href names
        // that task move, which is the whole of the backend's chat read state.
        for (final row in notifications) {
          if (row['type'] == 'CHAT_MESSAGE' &&
              row['readAt'] == null &&
              (row['href'] == '/messages?task=$taskId' ||
                  row['href'] == '/admin/messages?task=$taskId' ||
                  row['href'] == '/admin/chat/$taskId')) {
            row['readAt'] = now;
          }
        }
        return _json(200, {'ok': true});
      }
      if (id is! String) return _json(400, {'error': 'Missing id'});
      final matches = notifications.where((each) => each['id'] == id).toList();
      if (matches.isEmpty) return _json(200, {'ok': true});
      final row = matches.first;
      if (body['dismiss'] == true) {
        row['dismissedAt'] = now;
        row['readAt'] = now;
      } else if (body['related'] == true) {
        // The real route matches every unread row sharing this row's href.
        for (final other in notifications) {
          if (other['type'] == row['type'] &&
              other['href'] == row['href'] &&
              other['readAt'] == null) {
            other['readAt'] = now;
          }
        }
      } else {
        row['readAt'] = now;
      }
      return _json(200, {'ok': true});
    }

    // Mirrors src/app/api/tasks/[id]/chat/route.ts, in the order its own checks
    // run: session, suspension, hire, shape, task, closure.
    final chat = _chatRoute.firstMatch(path);
    if (chat != null) {
      return await _taskChat(request, chat.group(1)!);
    }

    if (path == '/api/auth/csrf' && method == 'GET') {
      return _json(
        200,
        {'csrfToken': csrfToken},
        headers: {
          'set-cookie':
              'next-auth.csrf-token=$csrfToken%7Chash; Path=/; SameSite=Lax',
        },
      );
    }

    if (path == '/api/auth/register' && method == 'POST') {
      // A round trip outlives the frame, the way a real one does, so the app's
      // busy state can be observed.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return _register(request);
    }

    if (path == '/api/auth/callback/credentials' && method == 'POST') {
      return _credentials(request);
    }

    if (path == '/api/auth/mobile-google' && method == 'POST') {
      return _mobileGoogle(request);
    }

    if (path == '/api/auth/session' && method == 'GET') {
      if (sessionBroken) {
        throw http.ClientException('Could not reach the server.');
      }
      final cookie = request.headers['cookie'] ?? '';
      final signedIn =
          _sessionIssued &&
          !sessionRevoked &&
          cookie.contains('next-auth.session-token');
      return _json(
        200,
        signedIn
            ? {
                'user': {
                  'id': sessionId,
                  // The JWT is rebuilt from the database row at each sign-in,
                  // so a name the contact or profile route wrote is what a
                  // re-login reports.
                  'name': storedName,
                  'email': validEmail,
                  // `authorize()` returns no image for a credentials login and
                  // the jwt callback only carries id and role, so this is null
                  // however many avatars the account has stored — [sessionImage]
                  // is how a test gives the session one anyway.
                  'image': sessionImage,
                  'role': sessionRole,
                },
                'expires': '2030-01-01T00:00:00.000Z',
              }
            : <String, dynamic>{},
      );
    }

    // Mirrors the GET half of src/app/api/profile/route.ts: the selected columns
    // its `select` names, plus every row of the five section tables that belongs
    // to this account, in the shape those routes' own answers use. Nothing but
    // the cookie decides whose profile this is.
    if (path == '/api/profile' && method == 'GET') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      if (profileReadBroken) {
        throw http.ClientException('Could not reach the server.');
      }
      if (profileReadMalformed) {
        return _json(200, {'languages': [], 'portfolio': []});
      }
      if (slowProfileRead) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      final mine = profileOwner == sessionId;
      return _json(200, {
        'user': {
          'name': storedName,
          'title': mine ? storedTitle : null,
          'bio': mine ? storedBio : null,
          'skills': mine ? storedSkills : null,
          'hourlyRate': mine ? storedHourlyRate : null,
          'avatarUrl': mine ? storedAvatarUrl : null,
          'videoIntroUrl': mine ? storedVideoIntro : null,
          'githubUrl': mine ? storedGithubUrl : null,
          'websiteUrl': mine ? storedWebsiteUrl : null,
          'youtubeUrl': mine ? storedYoutubeUrl : null,
        },
        'languages': _table('languages'),
        'education': _table('education'),
        'certifications': _table('certifications'),
        'employment': _table('employment'),
        'portfolio': _table('portfolio'),
      });
    }

    // Mirrors src/app/api/profile/route.ts: replace-not-merge, `name` checked
    // by profileSchema, and a JWT session whose user never changes after a
    // write — so this fake keeps answering with the sign-in name above.
    if (path == '/api/profile' && method == 'PATCH') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      final body = bodyFor(path);
      profileUpdate = body;
      final name = body['name'];
      final rate = body['hourlyRate'];
      final slugs = body['interestSlugs'];
      final valid =
          name is String &&
          name.trim().length >= 2 &&
          name.trim().length <= 80 &&
          _short(body['title'], 120) &&
          _short(body['bio'], 2000) &&
          _short(body['skills'], 500) &&
          _short(body['workGoal'], 300) &&
          _short(body['phone'], 20) &&
          _short(body['city'], 60) &&
          _short(body['country'], 60) &&
          _short(body['timezone'], 80) &&
          _short(body['stateProvince'], 80) &&
          _short(body['githubUrl'], 300) &&
          _short(body['websiteUrl'], 300) &&
          _short(body['youtubeUrl'], 300) &&
          _enum(body['experienceLevel'], const [
            'BEGINNER',
            'INTERMEDIATE',
            'PRO',
          ]) &&
          _enum(body['profileVisibility'], const ['PUBLIC', 'PRIVATE']) &&
          _enum(body['earningPrivacy'], const [
            'EVERYONE',
            'CLIENTS',
            'ONLY_ME',
          ]) &&
          (slugs == null ||
              (slugs is List &&
                  slugs.length <= 12 &&
                  slugs.every((slug) => slug is String && slug.isNotEmpty))) &&
          (rate == null || (rate is num && rate >= 0 && rate <= 10000));
      if (!valid) return _json(400, {'error': 'Invalid profile data'});
      storedName = name;
      // The route writes `d.field || null` for each of these, so a body that
      // leaves one out clears the column rather than keeping it.
      storedTitle = body['title'] is String ? body['title'] as String : null;
      storedBio = body['bio'] is String ? body['bio'] as String : null;
      storedSkills = body['skills'] is String ? body['skills'] as String : null;
      storedHourlyRate = rate is num ? rate.toDouble() : null;
      storedWorkGoal = _column(body['workGoal']);
      security['phone'] = _column(body['phone']);
      for (final key in const ['timezone', 'country', 'city']) {
        storedLocation[key] = body[key] is String ? body[key] as String : '';
      }
      // `experienceLevel: d.experienceLevel || undefined` — Prisma reads the
      // undefined as "leave the column alone", unlike every other column here.
      final level = body['experienceLevel'];
      if (level is String && level.isNotEmpty) {
        storedExperienceLevel = level;
      }
      // `stateProvince` and the five settings columns are spread in only when
      // the body carries the key, so an unaware client cannot clear them.
      if (body.containsKey('stateProvince')) {
        storedLocation['stateProvince'] = body['stateProvince'] is String
            ? body['stateProvince'] as String
            : '';
      }
      if (body.containsKey('githubUrl')) {
        storedGithubUrl = _column(body['githubUrl']);
      }
      if (body.containsKey('websiteUrl')) {
        storedWebsiteUrl = _column(body['websiteUrl']);
      }
      if (body.containsKey('youtubeUrl')) {
        storedYoutubeUrl = _column(body['youtubeUrl']);
      }
      if (body.containsKey('profileVisibility')) {
        storedVisibility = _column(body['profileVisibility']);
      }
      if (body.containsKey('earningPrivacy')) {
        storedEarningPrivacy = _column(body['earningPrivacy']);
      }
      if (slugs is List) {
        // The route resolves each slug against the `Category` table, so an
        // unknown one simply does not come back in the stored JSON.
        storedInterestSlugs = [
          for (final slug in slugs)
            if (slug is String && _isKnownSlug(slug)) slug,
        ];
      }
      storedAvatarUrl = body.containsKey('avatarUrl')
          ? body['avatarUrl'] as String?
          : storedAvatarUrl;
      profileOwner = sessionId;
      return _json(200, {
        'user': {'id': sessionId, 'name': name, 'avatarUrl': storedAvatarUrl},
      });
    }

    // Mirrors src/app/api/profile/avatar/route.ts: one `file` part, at most
    // 10MB, JPG/PNG/WEBP only, and the stored URL comes back in `url`.
    if (path == '/api/profile/avatar' && method == 'POST') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      final part = _multipartPart(request);
      if (part == null) return _json(400, {'error': 'Photo required'});
      if (part.bytes > 10 * 1024 * 1024) {
        return _json(400, {'error': 'File too large (max 10MB).'});
      }
      if (!const [
        'image/jpeg',
        'image/png',
        'image/webp',
      ].contains(part.type)) {
        return _json(400, {'error': 'Allowed photo formats: JPG, PNG, WEBP.'});
      }
      storedAvatarUrl = 'https://cdn.example/${part.filename}';
      profileOwner = sessionId;
      return _json(200, {'url': storedAvatarUrl});
    }

    if (path == '/api/profile/avatar' && method == 'DELETE') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      storedAvatarUrl = null;
      profileOwner = sessionId;
      return _json(200, {'ok': true});
    }

    // Mirrors src/app/api/upload/route.ts: proposal attachments accept common
    // images and documents, up to 10 MB, and answer with the stored URL.
    if (path == '/api/upload' && method == 'POST') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      final part = _multipartPart(request);
      if (part == null) return _json(400, {'error': 'File required'});
      if (part.bytes > 10 * 1024 * 1024) {
        return _json(400, {'error': 'File too large (max 10MB).'});
      }
      if (!_proposalUploadTypes.contains(part.type)) {
        return _json(400, {
          'error': 'Allowed: JPG, PNG, WEBP, PDF, DOC, DOCX.',
        });
      }
      return _json(200, {
        'url': 'https://cdn.example/${part.filename}',
        'filename': part.filename,
        'size': part.bytes,
      });
    }

    // Mirrors src/app/api/profile/portfolio/media/route.ts: one `file` part,
    // 60MB, a MIME allow-list that decides the `mediaType` returned.
    if (path == '/api/profile/portfolio/media' && method == 'POST') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      final part = _multipartPart(request);
      if (part == null) return _json(400, {'error': 'Media file required.'});
      if (part.bytes > 60 * 1024 * 1024) {
        return _json(400, {'error': 'Media file exceeds 60MB.'});
      }
      final kind = _mediaTypes[part.type];
      if (kind == null) {
        return _json(400, {'error': 'This media format is not supported.'});
      }
      return _json(200, {
        'url': 'https://cdn.example/${part.filename}',
        'mediaType': kind,
        'filename': part.filename,
      });
    }

    // Mirrors src/app/api/profile/video-intro/route.ts: the route stores a
    // link, never a file, and rejects anything that is not http(s).
    if (path == '/api/profile/video-intro') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      if (method == 'DELETE') {
        storedVideoIntro = null;
        profileOwner = sessionId;
        return _json(200, {'ok': true});
      }
      final url = (_body(request)['url'] as String?)?.trim() ?? '';
      final uri = Uri.tryParse(url);
      final webAddress =
          uri != null &&
          (uri.isScheme('http') || uri.isScheme('https')) &&
          uri.host.isNotEmpty;
      if (!webAddress) {
        return _json(400, {'error': 'Enter a valid video link.'});
      }
      storedVideoIntro = url;
      profileOwner = sessionId;
      return _json(200, {'url': url});
    }

    // Mirrors the five /api/profile/{collection} routes and their [id]
    // siblings: POST answers 201 {item}, PATCH {item}, DELETE {ok:true}, and a
    // row of another account reads as missing.
    final section = RegExp(
      r'^/api/profile/(languages|education|certifications|employment|portfolio)(?:/([^/]+))?$',
    ).firstMatch(path);
    if (section != null) {
      return _section(request, section.group(1)!, section.group(2));
    }

    // Mirrors src/app/api/account/security/route.ts: the GET reports the three
    // switches with the phone, providers and email around them, and the PATCH
    // writes only those switches.
    if (path == '/api/account/security') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      if (method == 'GET') {
        return _json(200, {
          'phone': security['phone'],
          'email': validEmail,
          'twoStepMobileApp': security['twoStepMobileApp'],
          'twoStepSms': security['twoStepSms'],
          'twoStepAuthenticator': security['twoStepAuthenticator'],
          'authenticatorConfigured': security['totpSecret'] != null,
          'googleLinked': security['googleId'] != null,
          'appleLinked': security['appleId'] != null,
          'appleAvailable': false,
        });
      }
      if (method != 'PATCH') return _json(405, {'error': 'Method not allowed'});
      final body = bodyFor(path);
      final shaped =
          body['twoStepMobileApp'] is bool &&
          body['twoStepSms'] is bool &&
          body['twoStepAuthenticator'] is bool;
      if (!shaped) {
        return _json(400, {'error': 'Invalid security settings.'});
      }
      final mobileApp = body['twoStepMobileApp'] as bool;
      final sms = body['twoStepSms'] as bool;
      final authenticator = body['twoStepAuthenticator'] as bool;
      final phone = security['phone'];
      if (sms && !(phone is String && phone.trim().isNotEmpty)) {
        return _json(400, {
          'error': 'Add a phone number to your profile before enabling SMS verification.',
        });
      }
      if (authenticator && security['totpSecret'] == null) {
        return _json(400, {
          'error': 'Set up an authenticator app before enabling authenticator codes.',
        });
      }
      security['twoStepMobileApp'] = mobileApp;
      security['twoStepSms'] = sms;
      security['twoStepAuthenticator'] = authenticator;
      if (!authenticator) security['totpSecret'] = null;
      return _json(200, {
        'ok': true,
        'twoStepMobileApp': mobileApp,
        'twoStepSms': sms,
        'twoStepAuthenticator': authenticator,
        'authenticatorConfigured': security['totpSecret'] != null,
      });
    }

    // Mirrors src/app/api/account/security/totp/route.ts: POST files a secret
    // the account cannot use yet, PUT promotes it only once a code matches it,
    // and DELETE takes both away. A secret on screen enables nothing.
    if (path == '/api/account/security/totp') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      if (method == 'POST') {
        const secret = 'JBSWY3DPEHPK3PXP';
        pendingTotpSecret = secret;
        security['twoStepAuthenticator'] = false;
        return _json(200, {
          'secret': secret,
          'otpauthUrl':
              'otpauth://totp/WorkingTrust:$validEmail'
              '?secret=$secret&issuer=WorkingTrust',
        });
      }
      if (method == 'PUT') {
        if (pendingTotpSecret == null) {
          return _json(400, {'error': 'Start authenticator setup first.'});
        }
        if (bodyFor(path)['code'] != validTotpCode) {
          return _json(400, {
            'error': 'Invalid authenticator code. Try again.',
          });
        }
        security['totpSecret'] = pendingTotpSecret;
        pendingTotpSecret = null;
        security['twoStepAuthenticator'] = true;
        return _json(200, {'ok': true});
      }
      if (method == 'DELETE') {
        pendingTotpSecret = null;
        security['totpSecret'] = null;
        security['twoStepAuthenticator'] = false;
        return _json(200, {'ok': true});
      }
      return _json(405, {'error': 'Method not allowed'});
    }

    // Mirrors src/app/api/account/security/sms/route.ts: the route refuses an
    // account with no phone, reports which way the code went, and only its PUT
    // turns the switch on.
    if (path == '/api/account/security/sms') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      if (method == 'POST') {
        final phone = security['phone'];
        if (phone is! String || phone.trim().isEmpty) {
          return _json(400, {
            'error': 'Add a phone number to your profile before enabling SMS verification.',
          });
        }
        smsSetupCode = validSmsCode;
        if (smsDeliveryFails) {
          return _json(200, {
            'ok': true,
            'channel': 'email',
            'message':
                'SMS provider unavailable. A setup code was sent to your email '
                'instead.',
          });
        }
        return _json(200, {
          'ok': true,
          'channel': 'sms',
          'message': 'A verification code was sent to your phone.',
        });
      }
      if (method == 'PUT') {
        final code = bodyFor(path)['code'];
        if (smsSetupCode == null || code != smsSetupCode) {
          return _json(400, {'error': 'Invalid or expired verification code.'});
        }
        smsSetupCode = null;
        security['twoStepSms'] = true;
        return _json(200, {'ok': true});
      }
      if (method == 'DELETE') {
        smsSetupCode = null;
        security['twoStepSms'] = false;
        return _json(200, {'ok': true});
      }
      return _json(405, {'error': 'Method not allowed'});
    }

    // Mirrors src/app/api/account/security/oauth/route.ts: a DELETE with a
    // provider in the JSON body is the only way this route changes anything,
    // and the credentials password is left alone.
    if (path == '/api/account/security/oauth' && method == 'DELETE') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      final provider = bodyFor(path)['provider'];
      if (provider != 'google' && provider != 'apple') {
        return _json(400, {'error': 'Invalid provider.'});
      }
      security[provider == 'google' ? 'googleId' : 'appleId'] = null;
      return _json(200, {'ok': true});
    }

    // Mirrors src/app/api/account/notifications/route.ts: the six keys are one
    // JSON column, all validated together, and the answer is always `prefs`.
    if (path == '/api/account/notifications') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      if (method == 'GET') {
        return _json(200, {'prefs': _prefs()});
      }
      if (method != 'PATCH') return _json(405, {'error': 'Method not allowed'});
      final body = bodyFor(path);
      final accepted =
          _level(body['desktopShow'], _activity) &&
          _level(body['desktopCounter'], _counter) &&
          _level(body['mobileShow'], _activity) &&
          _level(body['mobileCounter'], _counter) &&
          _level(body['emailShow'], _activity) &&
          _level(body['emailFrequency'], _frequency);
      if (!accepted) {
        return _json(400, {'error': 'Invalid notification preferences.'});
      }
      prefsColumn = jsonEncode(<String, String>{
        for (final key in const [
          'desktopShow',
          'desktopCounter',
          'mobileShow',
          'mobileCounter',
          'emailShow',
          'emailFrequency',
        ])
          key: body[key] as String,
      });
      return _json(200, {'ok': true, 'prefs': _prefs()});
    }

    // Mirrors src/app/api/account/contact/route.ts: PATCH-only, split by
    // `section`, and the account section warns about re-verification whenever
    // the email actually moves.
    if (path == '/api/account/contact' && method == 'PATCH') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      final body = bodyFor(path);
      final section = body['section'];
      if (section == 'account') {
        final name = body['name'];
        final email = body['email'];
        final shaped =
            name is String &&
            name.trim().length >= 2 &&
            name.trim().length <= 80 &&
            email is String &&
            email.contains('@') &&
            email.length <= 120;
        if (!shaped) {
          return _json(400, {
            'error': 'Enter a valid name (2+ characters) and email.',
          });
        }
        if (email == takenEmail) {
          return _json(400, {'error': 'That email is already in use.'});
        }
        final changed = email != validEmail;
        storedName = name.trim();
        return _json(200, {
          'ok': true,
          'user': {
            'id': sessionId,
            'name': storedName,
            'email': email,
            'emailVerified': !changed,
          },
          'message': changed
              ? 'Account updated. Please verify your new email before the next '
                    'login.'
              : 'Account details saved.',
        });
      }
      if (section == 'location') {
        const keys = ['timezone', 'country', 'stateProvince', 'city'];
        // `contactLocationSchema`: every value optional, empty allowed, at most
        // 80 characters.
        final shaped = keys.every((key) {
          final value = body[key];
          return value == null ||
              (value is String && value.trim().length <= 80);
        });
        if (!shaped) return _json(400, {'error': 'Invalid location details.'});
        for (final key in keys) {
          final value = body[key];
          storedLocation[key] = (value is String ? value : '').trim();
        }
        return _json(200, {
          'ok': true,
          'user': {for (final key in keys) key: storedLocation[key]},
          'message': 'Location details saved.',
        });
      }
      return _json(400, {'error': 'Unknown contact section.'});
    }

    // Mirrors src/app/api/account/password/route.ts: the route compares the
    // current password itself and refuses a repeat of it.
    if (path == '/api/account/password' && method == 'POST') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      final body = bodyFor(path);
      final current = body['currentPassword'];
      final next = body['newPassword'];
      final confirm = body['confirmPassword'];
      if (current is! String || current.isEmpty) {
        return _json(400, {
          'error': 'New password must be at least 8 characters.',
        });
      }
      if (next is! String ||
          next.length < 8 ||
          confirm is! String ||
          confirm.length < 8) {
        return _json(400, {
          'error': next != confirm
              ? 'New password and confirmation do not match.'
              : 'New password must be at least 8 characters.',
        });
      }
      if (next != confirm) {
        return _json(400, {
          'error': 'New password and confirmation do not match.',
        });
      }
      if (current != storedPassword) {
        return _json(400, {'error': 'Current password is incorrect.'});
      }
      if (next == storedPassword) {
        return _json(400, {
          'error': 'New password must be different from your current password.',
        });
      }
      storedPassword = next;
      return _json(200, {'ok': true});
    }

    // Mirrors src/app/api/account/billing/route.ts: the account keeps one
    // payment method, a card survives only as its last four digits, and the CVV
    // is validated then dropped.
    if (path == '/api/account/billing') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      if (method == 'GET') {
        return _json(200, {
          'method': billingMethods.isEmpty ? null : billingMethods.first,
          'methods': billingMethods,
        });
      }
      if (method == 'DELETE') {
        billingMethods.clear();
        return _json(200, {'ok': true, 'method': null, 'methods': []});
      }
      if (method != 'POST') return _json(405, {'error': 'Method not allowed'});
      final body = bodyFor(path);
      final type = body['method'];
      if (!const ['CARD', 'JAZZCASH', 'EASYPAISA'].contains(type)) {
        return _json(400, {'error': 'Choose a valid method.'});
      }
      final createdAt = DateTime.now().toUtc().toIso8601String();
      if (type == 'CARD') {
        final number = _digits(_trim(body['cardNumber']));
        final firstName = _trim(body['firstName']);
        final lastName = _trim(body['lastName']);
        final expMonth = _trim(body['expMonth']);
        final expYear = _trim(body['expYear']);
        final securityCode = _trim(body['securityCode']);
        if (number.length < 13 || number.length > 19) {
          return _json(400, {'error': 'Enter a valid card number.'});
        }
        if (firstName.isEmpty || firstName.length > 80) {
          return _json(400, {'error': 'Enter your first name.'});
        }
        if (lastName.isEmpty || lastName.length > 80) {
          return _json(400, {'error': 'Enter your last name.'});
        }
        if (!RegExp(r'^(0?[1-9]|1[0-2])$').hasMatch(expMonth)) {
          return _json(400, {'error': 'Enter a valid expiration month (MM).'});
        }
        if (!RegExp(r'^\d{4}$').hasMatch(expYear) &&
            !RegExp(r'^\d{2}$').hasMatch(expYear)) {
          return _json(400, {'error': 'Enter a valid expiration year (YYYY).'});
        }
        if (!RegExp(r'^\d{3,4}$').hasMatch(securityCode)) {
          return _json(400, {'error': 'Enter a valid security code.'});
        }
        final month = expMonth.padLeft(2, '0');
        final year = expYear.length == 2 ? '20$expYear' : expYear;
        final last4 = number.substring(number.length - 4);
        final holder = [firstName, lastName].join(' ');
        final holderLabel = holder.isEmpty ? 'Debit or credit card' : holder;
        final row = <String, dynamic>{
          'id': 'bm_${_methodSequence++}',
          'method': 'CARD',
          'label': 'Debit or credit card',
          'firstName': firstName,
          'lastName': lastName,
          'cardLast4': last4,
          'expMonth': month,
          'expYear': year,
          'accountDetails': '',
          'createdAt': createdAt,
        };
        row['accountDetails'] = '$holderLabel ···· $last4 · Exp $month/$year';
        // One method per account: the route replaces whatever was saved.
        billingMethods
          ..clear()
          ..add(row);
        return _json(201, {
          'ok': true,
          'method': row,
          'methods': [row],
        });
      }
      final accountName = _trim(body['accountName']);
      final walletAccount = _trim(body['walletAccount']);
      final label = type == 'JAZZCASH' ? 'JazzCash' : 'EasyPaisa';
      if (accountName.length < 2 || accountName.length > 80) {
        return _json(400, {'error': 'Enter the account name.'});
      }
      if (walletAccount.length < 5 || walletAccount.length > 80) {
        return _json(400, {
          'error': 'Enter a valid $label account number (5–80 characters).',
        });
      }
      final row = <String, dynamic>{
        'id': 'bm_${_methodSequence++}',
        'method': type,
        'label': label,
        'accountName': accountName,
        'walletAccount': walletAccount,
        'accountDetails': '$accountName · $walletAccount',
        'createdAt': createdAt,
      };
      billingMethods
        ..clear()
        ..add(row);
      return _json(201, {
        'ok': true,
        'method': row,
        'methods': [row],
      });
    }

    // Mirrors src/app/api/account/withdrawals/route.ts: a list of up to five
    // accounts in its own column, which no billing write touches.
    if (path == '/api/account/withdrawals') {
      if (sessionRevoked || !_hasSession(request)) {
        return _json(401, {'error': 'Unauthorized'});
      }
      if (method == 'GET') {
        return _json(200, {'methods': withdrawalMethods});
      }
      if (method == 'DELETE') {
        final id = bodyFor(path)['id'];
        if (id is! String || id.isEmpty) {
          return _json(400, {'error': 'Missing method id.'});
        }
        withdrawalMethods.removeWhere((row) => row['id'] == id);
        return _json(200, {'ok': true, 'methods': withdrawalMethods});
      }
      if (method != 'POST') return _json(405, {'error': 'Method not allowed'});
      final body = bodyFor(path);
      final type = body['method'];
      if (!const ['EASYPAISA', 'JAZZCASH', 'BANK_TRANSFER'].contains(type)) {
        return _json(400, {'error': 'Choose a valid method.'});
      }
      final details = _trim(body['accountDetails']);
      if (details.length < 5 || details.length > 300) {
        return _json(400, {
          'error': 'Enter valid account details (5–300 characters).',
        });
      }
      final label = _trim(body['label']);
      if (withdrawalMethods.length >= 5) {
        return _json(400, {
          'error': 'You can save up to 5 withdrawal methods.',
        });
      }
      withdrawalMethods.add(<String, dynamic>{
        'id': 'wm_${_methodSequence++}',
        'method': type,
        'accountDetails': details,
        'label': label.isEmpty
            ? (type == 'BANK_TRANSFER'
                  ? 'Bank transfer'
                  : type == 'JAZZCASH'
                  ? 'JazzCash'
                  : 'EasyPaisa')
            : (label.length > 80 ? label.substring(0, 80) : label),
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      return _json(201, {'ok': true, 'methods': withdrawalMethods});
    }

    if (path == '/api/auth/forgot-password' && method == 'POST') {
      final email = bodyFor(path)['email'];
      return _json(200, {
        'success': true,
        'message': email is String && email.isNotEmpty
            ? 'If an account exists with this email, a 6-digit verification '
                  'code has been sent.'
            : 'Email is required.',
      });
    }

    if (path == '/api/auth/verify-otp' && method == 'POST') {
      final body = bodyFor(path);
      if (body['otp'] == validOtp && body['email'] == validEmail) {
        return _json(200, {
          'success': true,
          'message': 'OTP verified successfully.',
          'resetToken': resetToken,
        });
      }
      return _json(400, {
        'success': false,
        'error': 'This OTP is incorrect. Please try again.',
      });
    }

    if (path == '/api/auth/reset-password' && method == 'POST') {
      final body = bodyFor(path);
      if (body['token'] == resetToken &&
          (body['password'] as String?)!.length >= 8) {
        return _json(200, {
          'success': true,
          'message': 'Password reset successfully. You can now log in.',
        });
      }
      return _json(400, {
        'error': 'This password reset link is invalid or has expired.',
      });
    }

    return _json(404, {'error': 'No fake route for $method $path'});
  }

  static final RegExp _chatRoute = RegExp(r'^/api/tasks/([^/]+)/chat$');
  static final RegExp _bidRoute = RegExp(r'^/api/tasks/([^/]+)/bid$');

  /// One `Task` row as `findWorkTasks`' select sends it: the category arrives
  /// nested, `requirements`, `deliverables` and `status` never arrive at all.
  Map<String, dynamic> _taskRow(Map<String, dynamic> row) => {
    'id': row['id'],
    'title': row['title'],
    'description': row['description'],
    'createdAt': row['createdAt'],
    'difficulty': row['difficulty'],
    'deadlineValue': row['deadlineValue'],
    'deadlineUnit': row['deadlineUnit'],
    'deadlineHours': row['deadlineHours'],
    'connectsCost': row['connectsCost'],
    'submittedProposals': row['submittedProposals'],
    'earningAmount': row['earningAmount'],
    'clientName': row['clientName'],
    'clientAvatarUrl': row['clientAvatarUrl'],
    'clientCountry': row['clientCountry'],
    'clientRating': row['clientRating'],
    'clientTotalSpent': row['clientTotalSpent'],
    'paymentVerified': row['paymentVerified'],
    'category': {'name': row['categoryName']},
    'client': {'rating': row['clientRating']},
    'bids': const [],
  };

  /// One request against `/api/tasks/[id]/bid`.
  /// Files one `Package` row, in that table's own columns, the way the admin
  /// route does. `features` is stored as the JSON string the text column holds,
  /// because that is the shape a read serializes.
  void seedPackage(
    String id, {
    required String name,
    String kind = 'BIDS',
    required double priceUsd,
    required int connects,
    String? description,
    int? validityDays,
    List<String> features = const [],
    String? audience,
    bool featured = false,
    bool active = true,
    int sortOrder = 0,
    double? serviceFeePct,
  }) {
    packages.add({
      'id': id,
      'name': name,
      'kind': kind,
      'priceUsd': priceUsd,
      'connects': connects,
      'description': description,
      'validityDays': validityDays,
      'features': features.isEmpty ? null : jsonEncode(features),
      'audience': audience,
      'featured': featured,
      'active': active,
      'sortOrder': sortOrder,
      'serviceFeePct': serviceFeePct,
    });
  }

  /// `GET /api/packages?kind=` — active rows of the asked kind, in the Admin
  /// Panel's order. A kind the table does not use is refused before any row is
  /// read, and a broken table answers 500 rather than an empty list.
  Future<http.Response> _packageList(http.Request request) async {
    if (packagesBroken) {
      return _json(500, {'error': 'Unable to load packages.'});
    }
    if (slowPackages) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    final asked = request.url.queryParameters['kind']?.trim().toUpperCase();
    const kinds = ['BIDS', 'MEMBERSHIP'];
    if (asked != null && asked.isNotEmpty && !kinds.contains(asked)) {
      return _json(400, {'error': 'Invalid kind. Use ${kinds.join(' or ')}.'});
    }

    final rows =
        packages.where((row) {
          if (row['active'] == false) return false;
          if (asked == null || asked.isEmpty) return true;
          return _kindOf(row) == asked;
        }).toList()..sort((a, b) {
          final byOrder = (a['sortOrder'] as int).compareTo(
            b['sortOrder'] as int,
          );
          if (byOrder != 0) return byOrder;
          return (a['priceUsd'] as double).compareTo(b['priceUsd'] as double);
        });
    return _json(200, {
      'packages': [for (final row in rows) _packageRow(row)],
    });
  }

  /// `isMembershipPackage`'s rule: the column when it says one, otherwise the
  /// three tier names the checkout route still recognises.
  String _kindOf(Map<String, dynamic> row) {
    final stored = row['kind'];
    if (stored == 'MEMBERSHIP' || stored == 'BIDS') return stored;
    const plans = ['starter', 'growth', 'pro'];
    return plans.contains('${row['name']}'.trim().toLowerCase())
        ? 'MEMBERSHIP'
        : 'BIDS';
  }

  /// One row as the route serialises it: the `features` text column goes out as
  /// the array the admin panel parsed it into, and no Stripe configuration is
  /// ever part of it.
  Map<String, dynamic> _packageRow(Map<String, dynamic> row) {
    final stored = row['features'];
    return {
      ...row,
      'kind': _kindOf(row),
      'features': stored == null
          ? const <String>[]
          : (jsonDecode(stored as String) as List).cast<String>(),
    };
  }

  /// Mirrors `src/app/api/deposits/stripe/checkout/route.ts`. The package id is
  /// the only thing the app decides; the amount, the connects and the mode all
  /// come off the server's own row.
  http.Response _stripeCheckout(http.Request request) {
    if (sessionRevoked || !_hasSession(request)) {
      return _json(401, {'error': 'Unauthorized'});
    }
    final body = _body(request);
    final packageId = body['packageId'];
    if (packageId is! String || packageId.isEmpty) {
      return _json(400, {'error': 'Package is required.'});
    }
    Map<String, dynamic>? pack;
    for (final row in packages) {
      if (row['id'] == packageId) pack = row;
    }
    if (pack == null || pack['active'] == false) {
      return _json(400, {'error': 'Invalid package.'});
    }
    final purpose = body['purpose'] == 'bids' ? 'bids' : 'membership';
    final kind = pack['kind'] ?? 'BIDS';
    if (purpose == 'membership' && kind != 'MEMBERSHIP') {
      return _json(400, {'error': 'Invalid membership plan.'});
    }
    if (purpose == 'bids' && kind != 'BIDS') {
      return _json(400, {'error': 'Invalid Buy Bids package.'});
    }
    // `stripePriceIdForBids` keys the Stripe Price by a bid pack's connects and
    // `stripePriceIdForPlan` by a plan's name, so a row outside those cannot be
    // checked out at all.
    final priced = purpose == 'bids'
        ? const [20, 50, 100].contains(pack['connects'])
        : const [
            'starter',
            'growth',
            'pro',
          ].contains((pack['name'] as String).trim().toLowerCase());
    if (!priced) {
      return _json(500, {
        'error': purpose == 'bids'
            ? 'No Stripe Price ID configured for ${pack['connects']} Bids.'
            : 'No Stripe Price ID configured for plan "${pack['name']}".',
      });
    }
    final stripeSession = 'cs_test_${++_depositSequence}';
    deposits[stripeSession] = <String, dynamic>{
      'id': 'd$_depositSequence',
      'userId': sessionId,
      'packageId': pack['id'],
      'planName': pack['name'],
      'purpose': purpose,
      'amountUsd': pack['priceUsd'],
      'connects': pack['connects'],
      'status': 'PENDING',
      'fulfilled': false,
      // `Deposit.createdAt` is the table's `@default(now())`, and both the
      // wallet's pending row and the transaction feed order on it.
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    return _json(200, {
      'success': true,
      'checkoutUrl': 'https://checkout.stripe.com/c/pay/$stripeSession',
      'sessionId': stripeSession,
    });
  }

  /// Mirrors `src/app/api/deposits/stripe/confirm/route.ts`, which is the only
  /// answer a device can get about a payment — including the 409 it gives while
  /// Stripe has not reported one.
  http.Response _stripeConfirm(http.Request request) {
    if (sessionRevoked || !_hasSession(request)) {
      return _json(401, {'error': 'Unauthorized'});
    }
    final body = _body(request);
    final stripeSession = body['sessionId'];
    if (stripeSession is! String || stripeSession.isEmpty) {
      return _json(400, {'error': 'Stripe session id is required.'});
    }
    final deposit = deposits[stripeSession];
    if (deposit == null) return _json(404, {'error': 'Deposit not found.'});
    if (paymentUnpaid) {
      return _json(409, {
        'error': 'Payment is not completed yet.',
        'paymentStatus': 'open',
      });
    }
    final alreadyFulfilled = deposit['fulfilled'] == true;
    deposit['fulfilled'] = true;
    deposit['status'] = 'PAID';
    // `fulfillStripeDeposit`: the connects land on the account here, and a
    // second confirm of the same session changes nothing.
    if (!alreadyFulfilled && deposit['purpose'] == 'bids') {
      storedConnects += deposit['connects'] as int;
    }
    return _json(200, {
      'ok': true,
      'purpose': deposit['purpose'],
      'planName': deposit['planName'],
      'connects': deposit['connects'],
      'stripeSubscriptionId': deposit['purpose'] == 'membership'
          ? 'sub_fake'
          : null,
      'alreadyFulfilled': alreadyFulfilled,
    });
  }

  http.Response _taskBid(http.Request request, String taskId) {
    if (sessionRevoked || !_hasSession(request)) {
      return _json(401, {'error': 'Unauthorized'});
    }
    final body = _body(request);
    final proposal = body['proposal'];
    final amount = body['bidAmount'];
    final extra = body['extraConnects'];
    // `bidSchema`: a 20-to-3000 character proposal, an optional rate between 5
    // and 10000, and every failure answered with the route's one sentence.
    final shaped =
        proposal is String &&
        proposal.trim().length >= 20 &&
        proposal.trim().length <= 3000 &&
        (amount == null || (amount is num && amount >= 5 && amount <= 10000)) &&
        (extra == null || (extra is num && extra >= 0 && extra <= 200));
    if (!shaped) {
      return _json(400, {
        'error': 'Write a clear proposal (min 20 characters).',
      });
    }
    Map<String, dynamic>? task;
    for (final row in tasks) {
      if (row['id'] == taskId) task = row;
    }
    if (task == null || task['status'] != 'OPEN') {
      return _json(400, {
        'error': 'This project is not open for applications.',
      });
    }
    if (bids.any(
      (row) => row['taskId'] == taskId && row['userId'] == sessionId,
    )) {
      return _json(400, {'error': 'You already applied on this project.'});
    }
    if (accountSuspended) {
      return _json(403, {'error': 'Account suspended.'});
    }
    final cost =
        (task['connectsCost'] as int) + (extra is num ? extra.round() : 0);
    if (storedConnects < cost) {
      return _json(400, {'error': 'Not enough connects. Buy a package first.'});
    }
    storedConnects -= cost;
    final row = <String, dynamic>{
      'id': 'b${++_bidSequence}',
      'userId': sessionId,
      'taskId': taskId,
      'proposal': proposal.trim(),
      'bidAmount': amount,
      'extraConnects': extra is num ? extra.round() : 0,
      'connectsSpent': cost,
      'attachmentUrls': body['attachmentUrls'],
      'portfolioItemIds': body['portfolioItemIds'],
      'status': 'PENDING',
      // `Bid.createdAt` is the table's `@default(now())`; `/api/bids/my` and
      // the proposal funnel both order and window on it.
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    bids.add(row);
    // The route increments the counter in the same transaction.
    task['submittedProposals'] = (task['submittedProposals'] as int) + 1;
    return _json(201, {'bid': row});
  }

  /// One request against `/api/tasks/[id]/chat`, answered with the backend's
  /// own sentences and the labels its `presentMessage` writes.
  Future<http.Response> _taskChat(http.Request request, String taskId) async {
    if (sessionRevoked || !_hasSession(request)) {
      return _json(401, {'error': 'Unauthorized'});
    }
    final method = request.method;
    if (method == 'POST' && slowChat) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    final task = chatTasks[taskId];
    final admin = sessionRole == 'ADMIN';
    // `authorize`-free suspension check, which the POST route runs before it
    // even looks at the project.
    if (method == 'POST' && !admin && accountSuspended) {
      return _json(403, {'error': 'Account suspended.'});
    }
    if (!admin && task?['hired'] != true) {
      return _json(403, {
        'error': 'Chat unlocks only after you are hired on this project.',
      });
    }
    if (task == null) return _json(404, {'error': 'Not found'});
    if (chatBroken) return _json(500, 'Internal Server Error');
    final clientName = task['clientName'] as String;

    if (method == 'GET') {
      return _json(200, {
        'clientName': clientName,
        'clientAvatarUrl': task['clientAvatarUrl'],
        'freelancerName': task['freelancerName'],
        'freelancerAvatarUrl': task['freelancerAvatarUrl'],
        'projectTitle': task['title'],
        'flagged': task['chatFlagged'],
        'closed': task['chatClosed'],
        'messages': [
          for (final row in chatRows[taskId] ?? const [])
            _presentChat(row, clientName),
        ],
      });
    }
    if (method != 'POST') return _json(405, {'error': 'Method not allowed'});

    // `chatSchema`: either text is optional, but never both, and each has a
    // cap the route enforces before it reads the task.
    final body = _body(request);
    final text = body['body'] is String ? body['body'] as String : '';
    final file = body['attachmentUrl'] is String
        ? body['attachmentUrl'] as String
        : '';
    if (text.length > 2000 ||
        file.length > 500 ||
        (text.trim().isEmpty && file.isEmpty)) {
      return _json(400, {'error': 'Write a message or attach a file.'});
    }
    if (task['chatClosed'] == true) {
      return _json(403, {'error': 'This conversation is closed.'});
    }

    final row = {
      'id': 'm${++_chatSequence}',
      'senderId': sessionId,
      'sender': {
        'id': sessionId,
        'name': admin ? clientName : storedName,
        'role': sessionRole,
      },
      'body': text.trim(),
      'attachmentUrl': file.isEmpty ? null : file,
      'createdAt': DateTime.now().toUtc(),
    };
    chatRows.putIfAbsent(taskId, () => []).add(row);
    // The real route also notifies the other side; the app only ever reads its
    // own feed, so the fake leaves that row out.
    return _json(201, {
      'message': _presentChat(row, clientName),
      'clientName': clientName,
      'clientAvatarUrl': task['clientAvatarUrl'],
      'freelancerName': task['freelancerName'],
      'freelancerAvatarUrl': task['freelancerAvatarUrl'],
    });
  }

  /// `presentMessage`: the server decides who the reader sees, because a
  /// project's client is a name on the task rather than a login.
  Map<String, dynamic> _presentChat(
    Map<String, dynamic> row,
    String clientName,
  ) {
    final clientSide = row['sender']['role'] == 'ADMIN';
    return {
      'id': row['id'],
      'body': row['body'],
      'attachmentUrl': row['attachmentUrl'],
      'createdAt': (row['createdAt'] as DateTime).toIso8601String(),
      'senderId': row['senderId'],
      'displayName': sessionRole == 'ADMIN'
          ? (clientSide ? 'You (as $clientName)' : row['sender']['name'])
          : (clientSide ? clientName : 'You'),
      'isClientSide': clientSide,
    };
  }

  /// One request against a profile section collection, or one of its rows.
  http.Response _section(http.Request request, String collection, String? id) {
    if (sessionRevoked || !_hasSession(request)) {
      return _json(401, {'error': 'Unauthorized'});
    }
    final rows = sectionRows.putIfAbsent(collection, () => []);
    final method = request.method;
    if (id == null) {
      if (method != 'POST') return _json(405, {'error': 'Method not allowed'});
      final body = _body(request);
      final refused = _refusal(collection, body);
      if (refused != null) return _json(400, {'error': refused});
      final row = <String, dynamic>{
        'id': 'r${++_rowSequence}',
        'userId': sessionId,
        ...body,
      };
      rows.add(row);
      return _json(201, {'item': row});
    }
    final matches = rows.where((row) => row['id'] == id).toList();
    if (matches.isEmpty) return _json(404, {'error': 'Not found'});
    if (method == 'DELETE') {
      rows.remove(matches.first);
      return _json(200, {'ok': true});
    }
    if (method != 'PATCH') return _json(405, {'error': 'Method not allowed'});
    final body = _body(request);
    final refused = _refusal(collection, body);
    if (refused != null) return _json(400, {'error': refused});
    // A Prisma `update` writes the fields the route hands it and keeps the
    // rest, so the id and owner survive.
    final row = matches.first
      ..addEntries(body.entries)
      ..['id'] = id
      ..['userId'] = sessionId;
    return _json(200, {'item': row});
  }

  /// The fake rows of one section table as `GET /api/profile` sends them: only
  /// this account's, in the order they were created (the route's `sortOrder`),
  /// and in the types the database columns give — `PortfolioItem.skills` is a
  /// JSON array string and a `DateTime` column arrives as a timestamp.
  List<Map<String, dynamic>> _table(String collection) => [
    for (final row in sectionRows[collection] ?? const <Map<String, dynamic>>[])
      if (row['userId'] == sessionId)
        switch (collection) {
          'portfolio' => {
            ...row,
            'skills': row['skills'] is List
                ? jsonEncode(row['skills'])
                : row['skills'],
          },
          'employment' => {
            ...row,
            'startDate': _stamp(row['startDate']),
            'endDate': _stamp(row['endDate']),
          },
          'certifications' => {...row, 'issuedAt': _stamp(row['issuedAt'])},
          _ => row,
        },
  ];

  /// How a date the route stored comes back: `new Date(text)` on the way in, an
  /// ISO timestamp on the way out. An empty date is a null column.
  String? _stamp(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc().toIso8601String();
  }

  /// The zod schema behind [collection], answered with the route's own
  /// sentence. Null means the body is accepted.
  String? _refusal(String collection, Map<String, dynamic> body) {
    switch (collection) {
      case 'languages':
        return _text(body, 'name', 60) && _text(body, 'proficiency', 60)
            ? null
            : 'Invalid language data';
      case 'education':
        return _text(body, 'school', 160) &&
                _maybe(body, 'degree', 160) &&
                _maybe(body, 'fieldOfStudy', 160) &&
                _maybe(body, 'fromYear', 20) &&
                _maybe(body, 'toYear', 20) &&
                _maybe(body, 'description', 2000)
            ? null
            : 'Invalid education data';
      case 'certifications':
        return _text(body, 'title', 160) &&
                _text(body, 'provider', 160) &&
                _date(body, 'issuedAt') &&
                _maybe(body, 'certificateId', 120) &&
                _maybe(body, 'certificateUrl', 500) &&
                _maybe(body, 'description', 2000)
            ? null
            : 'Invalid certification data';
      case 'employment':
        final shaped =
            _text(body, 'title', 160) &&
            _text(body, 'company', 160) &&
            _text(body, 'startDate', 40) &&
            _maybe(body, 'endDate', 40) &&
            _maybe(body, 'description', 2000);
        if (!shaped) return 'Invalid employment data';
        // The route parses the dates itself, after the schema.
        if (DateTime.tryParse(body['startDate'] as String) == null) {
          return 'Invalid start date';
        }
        final end = body['endDate'];
        if (end is String && end.isNotEmpty && DateTime.tryParse(end) == null) {
          return 'Invalid end date';
        }
        return null;
      default:
        final media = body['imageUrl'];
        return _maybe(body, 'title', 70) &&
                _maybe(body, 'role', 100) &&
                _skillList(body['skills']) &&
                _maybe(body, 'description', 1200) &&
                _maybe(body, 'imageUrl', 500) &&
                _oneOf(body, 'mediaType', const [
                  'image',
                  'video',
                  'text',
                  'file',
                  'link',
                  'music',
                ]) &&
                _maybe(body, 'linkUrl', 500) &&
                _oneOf(body, 'status', const ['DRAFT', 'PUBLISHED']) &&
                (media is String && media.trim().isNotEmpty) &&
                (body['title'] is String &&
                    (body['title'] as String).trim().length >= 2)
            ? null
            : 'Invalid portfolio data';
    }
  }

  Map<String, dynamic> _body(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;

  static const List<String> _activity = ['ALL', 'IMPORTANT', 'NONE'];
  static const List<String> _counter = ['ALL', 'MESSAGES', 'NONE'];
  static const List<String> _frequency = [
    'IMMEDIATE',
    'DAILY',
    'WEEKLY',
    'NEVER',
  ];

  bool _level(Object? value, List<String> allowed) =>
      value is String && allowed.contains(value);

  /// `parseNotificationPrefs`: unreadable JSON or an unknown token falls back to
  /// the default for that key, never to an empty value.
  Map<String, String> _prefs() {
    Map<String, dynamic> stored = const {};
    final column = prefsColumn;
    if (column != null) {
      try {
        final decoded = jsonDecode(column);
        if (decoded is Map<String, dynamic>) stored = decoded;
      } on FormatException {
        stored = const {};
      }
    }
    String pick(String key, List<String> allowed, String fallback) {
      final value = stored[key];
      return value is String && allowed.contains(value) ? value : fallback;
    }

    return {
      'desktopShow': pick('desktopShow', _activity, 'ALL'),
      'desktopCounter': pick('desktopCounter', _counter, 'ALL'),
      'mobileShow': pick('mobileShow', _activity, 'ALL'),
      'mobileCounter': pick('mobileCounter', _counter, 'ALL'),
      'emailShow': pick('emailShow', _activity, 'ALL'),
      'emailFrequency': pick('emailFrequency', _frequency, 'IMMEDIATE'),
    };
  }

  /// A required text: zod's `min(1).max(n)`.
  bool _text(Map<String, dynamic> body, String key, int max) {
    final value = body[key];
    return value is String && value.isNotEmpty && value.length <= max;
  }

  /// An optional text, which zod also lets arrive empty or absent.
  bool _maybe(Map<String, dynamic> body, String key, int max) {
    final value = body[key];
    return value == null || (value is String && value.length <= max);
  }

  /// `issuedAt` is a plain `max(40)` string on the route, so only its length is
  /// checked — unlike employment, where a date the driver cannot read is a 400.
  bool _date(Map<String, dynamic> body, String key) => _maybe(body, key, 40);

  bool _skillList(Object? value) =>
      value == null ||
      (value is List &&
          value.length <= 5 &&
          value.every((skill) => skill is String && skill.length <= 40));

  bool _oneOf(Map<String, dynamic> body, String key, List<String> allowed) {
    final value = body[key];
    return value == null || (value is String && allowed.contains(value));
  }

  /// The media route's MIME allow-list, mapped to the `mediaType` it stores.
  static const Map<String, String> _mediaTypes = {
    'image/jpeg': 'image',
    'image/png': 'image',
    'image/webp': 'image',
    'video/mp4': 'video',
    'video/webm': 'video',
    'video/quicktime': 'video',
    'text/plain': 'text',
    'application/pdf': 'file',
    'text/csv': 'file',
    'application/zip': 'file',
    'application/x-zip-compressed': 'file',
    'application/msword': 'file',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        'file',
    'audio/mpeg': 'music',
    'audio/wav': 'music',
    'audio/ogg': 'music',
  };

  static const Set<String> _proposalUploadTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };

  http.Response _register(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final name = body['name'];
    final email = body['email'];
    final password = body['password'];
    final slugs = body['interestSlugs'];
    final level = body['experienceLevel'];
    final phone = body['phone'];

    // Mirrors registerSchema; the route answers every schema failure with the
    // same sentence.
    final shapeOk =
        name is String &&
        name.trim().length >= 2 &&
        name.trim().length <= 80 &&
        email is String &&
        email.contains('@') &&
        password is String &&
        password.length >= 8 &&
        password.length <= 100 &&
        slugs is List &&
        slugs.isNotEmpty &&
        slugs.length <= 12 &&
        slugs.every(_isKnownSlug) &&
        level is String &&
        const ['BEGINNER', 'INTERMEDIATE', 'PRO'].contains(level) &&
        (phone == null ||
            (phone is String && phone.length >= 10 && phone.length <= 20));
    if (!shapeOk) {
      return _json(400, {
        'error':
            'Please complete all steps — pick at least one field/interest.',
      });
    }
    if (email == takenEmail) {
      return _json(409, {'error': 'Email already registered. Please log in.'});
    }
    return _json(201, {
      'user': {
        'id': 'u-new',
        'email': email,
        'name': name,
        'interestSlugs': jsonEncode(slugs),
        'experienceLevel': level,
        'city': body['city'],
        'phone': phone,
      },
    });
  }

  /// Mirrors `src/app/api/auth/mobile-google/route.ts` in the same order: the
  /// ID token is checked first, then the account, and only a pass sets the
  /// NextAuth session cookie. The body is a courtesy — the app re-reads the
  /// session, so what follows the cookie is [sessionId] and [sessionImage] as
  /// always.
  http.Response _mobileGoogle(http.Request request) {
    final Object? body;
    try {
      body = jsonDecode(request.body);
    } on FormatException {
      return _json(400, {'error': 'Missing Google ID token.'});
    }
    final idToken = (body is Map<String, dynamic>) ? body['idToken'] : null;
    if (idToken is! String || idToken.isEmpty) {
      return _json(400, {'error': 'Missing Google ID token.'});
    }
    if (googleIdRejected || idToken != validGoogleIdToken) {
      return _json(401, {'error': 'Google did not accept that sign-in.'});
    }
    if (googleAccountSuspended) {
      return _json(403, {
        'error': 'Your account cannot sign in. Contact support.',
      });
    }
    _sessionIssued = true;
    return _json(
      200,
      {
        'message': 'Signed in.',
        'user': {
          'id': sessionId,
          'name': storedName,
          'email': validEmail,
          'image': sessionImage,
          'role': sessionRole,
        },
      },
      headers: {
        'set-cookie':
            'next-auth.session-token=$sessionCookieValue; Path=/; HttpOnly; SameSite=Lax',
      },
    );
  }

  http.Response _credentials(http.Request request) {
    final form = Uri.splitQueryString(request.body);
    if (form['json'] != 'true') {
      // Without json=true the real route answers with a bare 302.
      return _json(200, {'ok': true});
    }
    if (form['csrfToken'] != csrfToken) {
      return _json(200, {
        'url': 'http://localhost:3000/api/auth/signin?csrf=true',
      });
    }
    if (form['email'] == validEmail && form['password'] == validPassword) {
      _sessionIssued = true;
      return _json(
        302,
        {'url': 'http://localhost:3000/dashboard'},
        headers: {
          'set-cookie':
              'next-auth.session-token=$sessionCookieValue; Path=/; HttpOnly; SameSite=Lax',
        },
      );
    }
    if (form['email'] == unverifiedEmail) {
      // authorize() throws, and NextAuth puts the message in the error URL.
      return _json(401, {
        'url':
            'http://localhost:3000/api/auth/error?error=${Uri.encodeComponent('Please verify your email before logging in.')}',
      });
    }
    return _json(401, {
      'url': 'http://localhost:3000/api/auth/error?error=CredentialsSignin&provider=credentials',
    });
  }

  bool _isKnownSlug(Object? slug) =>
      slug is String && categories.any((c) => c['slug'] == slug);

  /// profileSchema caps each text field, and an absent field is as valid as an
  /// empty one.
  bool _short(Object? value, int max) =>
      value == null || (value is String && value.length <= max);

  /// A zod `enum`: the key may be absent, but a value the list does not name
  /// fails the schema and the route answers 400.
  bool _enum(Object? value, List<String> accepted) =>
      value == null || (value is String && accepted.contains(value));

  /// The route's `d.field || null` for a text column — absent, null or blank
  /// all end up as a null column.
  String? _column(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  /// A body value read the way `typeof body.x === "string" ? body.x.trim()`
  /// does: anything else is the empty string.
  String _trim(Object? value) => value is String ? value.trim() : '';

  /// The card number with every non-digit removed, as the route reduces it
  /// before it checks the length and keeps only the last four.
  String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

  /// Reads the single `file` part of a multipart upload the way `formData()`
  /// would: its declared name, file name, MIME type and size.
  ({String filename, String? type, int bytes})? _multipartPart(
    http.Request request,
  ) {
    final contentType = request.headers['content-type'] ?? '';
    final boundary = RegExp(r'boundary=([^;]+)')
        .firstMatch(contentType)
        ?.group(1);
    if (!contentType.startsWith('multipart/form-data') || boundary == null) {
      return null;
    }
    final text = utf8.decode(request.bodyBytes, allowMalformed: true);
    final head = text.split('--$boundary').skip(1).first;
    final headerEnd = head.indexOf('\r\n\r\n');
    if (headerEnd < 0) return null;
    final headers = head.substring(0, headerEnd);
    if (!headers.contains('name="file"')) return null;
    final filename = RegExp(r'filename="([^"]*)"')
        .firstMatch(headers)
        ?.group(1);
    if (filename == null || filename.isEmpty) return null;
    return (
      filename: filename,
      type: RegExp(r'Content-Type:\s*([^\r\n]+)')
          .firstMatch(headers)
          ?.group(1)
          ?.trim(),
      bytes: request.bodyBytes.length,
    );
  }

  /// Holds a finance read open while [slowFinance] is on, the way a slow Prisma
  /// query does on a real deployment.
  Future<http.Response> _await(http.Response response) async {
    if (slowFinance) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return response;
  }

  /// `POST /api/withdrawals` → `requestWorkWithdrawals`, in the route's own
  /// order: session, six-an-hour, `withdrawalSchema`, the billing method on
  /// file, then the transaction that prices each named job from its own row,
  /// decrements `walletBalance` and files one `Withdrawal` plus one debit
  /// ledger entry. A refusal happens before any of that, so a rejected request
  /// leaves every figure exactly where it was.
  http.Response _requestWithdrawal(http.Request request) {
    if (!_signedIn(request)) return _unauthorised();
    double round(double value) => double.parse(value.toStringAsFixed(2));
    final now = DateTime.now();
    _withdrawTimes
      ..removeWhere((each) => now.difference(each).inSeconds >= 3600)
      ..add(now);
    if (_withdrawTimes.length > 6) {
      final wait = 3600 - now.difference(_withdrawTimes.first).inSeconds;
      return _json(429, {
        'error': 'Too many withdrawal attempts. Try again in ${wait}s.',
      });
    }

    final raw = bodyFor('/api/withdrawals')['assignmentIds'];
    if (raw is! List || raw.isEmpty || raw.length > 20) {
      return _json(400, {'error': 'Invalid withdrawal data'});
    }
    if (raw.any((each) => each is! String || each.isEmpty)) {
      return _json(400, {'error': 'Invalid withdrawal data'});
    }
    final ids = raw.cast<String>().toSet().toList();
    if (billingMethods.isEmpty) {
      return _json(400, {
        'error': 'Add a payment method before requesting a withdrawal.',
        'code': 'NO_PAYMENT_METHOD',
      });
    }
    if (accountSuspended) return _json(403, {'error': 'Account suspended.'});

    final picked = <Map<String, dynamic>>[];
    for (final id in ids) {
      Map<String, dynamic>? row;
      for (final each in assignments) {
        if (each['id'] == id &&
            each['userId'] == sessionId &&
            each['status'] == 'APPROVED') {
          row = each;
          break;
        }
      }
      // The route compares what it found against what it asked for, so one
      // foreign, unapproved or missing job refuses the whole request.
      if (row == null) {
        return _json(400, {
          'error': 'Select approved work that has not been withdrawn.',
        });
      }
      if (_withdrawalFor(id) != null) {
        return _json(409, {
          'error': 'That approved work already has a withdrawal request.',
        });
      }
      picked.add(row);
    }

    final amounts = [
      for (final row in picked)
        round(
          (row['payoutAmount'] as num?)?.toDouble() ??
              (_taskById('${row['taskId']}')?['earningAmount'] as num?)
                  ?.toDouble() ??
              0,
        ),
    ];
    final total = round(amounts.fold<double>(0, (sum, each) => sum + each));
    if (total <= 0) {
      return _json(400, {
        'error': 'Select approved work that has not been withdrawn.',
      });
    }
    if (total > (storedBalance ?? 0)) {
      return _json(400, {
        'error': 'Insufficient wallet balance for the selected work.',
      });
    }

    final billing = billingMethods.first;
    final accountDetails = [
      billing['label'],
      billing['accountDetails'],
    ].where((each) => '${each ?? ''}'.trim().isNotEmpty).join('\n');
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final created = <Map<String, dynamic>>[
      for (int index = 0; index < picked.length; index++)
        <String, dynamic>{
          'id': 'nw${++_withdrawalSequence}',
          'userId': sessionId,
          'assignmentId': picked[index]['id'],
          'taskId': picked[index]['taskId'],
          'amount': amounts[index],
          'status': 'PENDING',
          'method': billing['method'],
          'accountDetails': accountDetails,
          'projectTitle': _taskById('${picked[index]['taskId']}')?['title'],
          'clientName': _taskById('${picked[index]['taskId']}')?['clientName'],
          'createdAt': createdAt,
        },
    ];
    withdrawals.addAll(created);
    storedBalance = round((storedBalance ?? 0) - total);
    walletTxs.add(<String, dynamic>{
      'id': 'tx-${created.first['id']}',
      'userId': sessionId,
      'type': 'DEBIT',
      'amount': -total,
      'reason':
          'Withdrawal request for ${created.length} approved job'
          '${created.length == 1 ? '' : 's'}',
      'refId': created.first['id'],
      'createdAt': createdAt,
    });
    return _json(201, {'withdrawals': created});
  }

  /// `GET /api/wallet` → `buildWalletSummary`.
  http.Response _wallet(http.Request request) {
    if (!_signedIn(request)) return _unauthorised();
    if (financeBroken) {
      return _json(500, {'error': 'Unable to load the wallet.'});
    }
    Map<String, dynamic>? pendingDeposit;
    for (final row in deposits.values) {
      if (row['status'] == 'PENDING') pendingDeposit = row;
    }
    final earnings = <Map<String, dynamic>>[];
    for (final row in _newestFirst(assignments, 'updatedAt')) {
      if (row['status'] != 'APPROVED') continue;
      final task = _taskById('${row['taskId']}');
      final payout = row['payoutAmount'];
      final withdrawal = _withdrawalFor('${row['id']}');
      earnings.add({
        'id': row['id'],
        'taskTitle': task?['title'] ?? 'Project',
        'clientName': _displayName(task?['clientName']),
        'amount':
            (payout as num?)?.toDouble() ??
            (task?['earningAmount'] as num?)?.toDouble() ??
            0,
        'updatedAt': row['updatedAt'],
        'withdrawalRequested': withdrawal != null,
        'withdrawalStatus': withdrawal?['status'],
      });
    }
    return _json(200, {
      'balance': storedBalance,
      'connects': storedConnects,
      // The page's own rule: connects on the account means a plan that can apply.
      'planActive': storedConnects > 0,
      'pendingDeposit': pendingDeposit == null
          ? null
          : {
              'id': pendingDeposit['id'],
              'packageName': pendingDeposit['planName'],
              'amountUsd': pendingDeposit['amountUsd'],
              'connects': pendingDeposit['connects'],
              'status': pendingDeposit['status'],
              'createdAt': pendingDeposit['createdAt'],
            },
      'earningsByJob': earnings,
      'transactions': [
        for (final row in _newestFirst(walletTxs, 'createdAt').take(30))
          {
            'id': row['id'],
            'type': row['type'],
            'amount': row['amount'],
            'reason': row['reason'],
            'refId': row['refId'],
            'createdAt': row['createdAt'],
          },
      ],
      'connectsActivity': [
        for (final row in _newestFirst(connectLedger, 'createdAt').take(20))
          {
            'id': row['id'],
            'delta': row['delta'],
            'reason': row['reason'],
            'refId': row['refId'],
            'createdAt': row['createdAt'],
          },
      ],
    });
  }

  /// `GET /api/reports/overview` → `buildReportsOverview`.
  http.Response _reportOverview(http.Request request) {
    if (!_signedIn(request)) return _unauthorised();
    if (financeBroken) {
      return _json(500, {'error': 'Unable to load the report overview.'});
    }
    double taskEarning(Map<String, dynamic> row) =>
        (_taskById('${row['taskId']}')?['earningAmount'] as num?)?.toDouble() ??
        0;
    final jobs = <Map<String, dynamic>>[];
    for (final row in _newestFirst(assignments, 'updatedAt')) {
      final status = '${row['status']}';
      if (!['ACTIVE', 'SUBMITTED', 'REJECTED'].contains(status)) continue;
      final task = _taskById('${row['taskId']}');
      jobs.add({
        'id': row['id'],
        'taskId': row['taskId'],
        'title': task?['title'] ?? 'Project',
        'description': task?['description'] ?? '',
        'status': status,
        'statusLabel': switch (status) {
          'SUBMITTED' => 'In review',
          'REJECTED' => 'Needs revision',
          _ => 'In progress',
        },
        'clientName': _displayName(task?['clientName']),
        'earningAmount': taskEarning(row),
        'dueAt': row['dueAt'],
      });
    }
    return _json(200, {
      'workInProgressAmount': _total(
        assignments.where((row) => row['status'] == 'ACTIVE'),
        taskEarning,
      ),
      'inReviewAmount': _total(
        assignments.where((row) => row['status'] == 'SUBMITTED'),
        taskEarning,
      ),
      'pendingWithdrawalsAmount': _total(
        withdrawals.where((row) => row['status'] == 'PENDING'),
        (row) => (row['amount'] as num?)?.toDouble() ?? 0,
      ),
      'availableBalance': storedBalance,
      'jobs': jobs,
    });
  }

  /// `GET /api/reports/transactions` → `buildTransactions`, including the three
  /// ledger reasons the page drops because an earning or withdrawal row already
  /// reports the same money.
  http.Response _transactions(http.Request request) {
    if (!_signedIn(request)) return _unauthorised();
    final params = request.url.queryParameters;
    final type = params['type'] ?? 'all';
    const accepted = [
      'all',
      'Client',
      'Withdrawal',
      'Bids',
      'Subscription',
      'Other',
      'Earning',
    ];
    if (!accepted.contains(type)) {
      return _json(400, {
        'error': 'Invalid type. Use all, Client, Withdrawal, Bids, Subscription or Other.',
      });
    }
    if (financeBroken) {
      return _json(500, {'error': 'Unable to load transactions.'});
    }
    final paging = _readPaging(params, defaultLimit: 50);
    final client = params['client'] ?? 'all';

    final rows = <Map<String, dynamic>>[];
    for (final row in deposits.values) {
      final buyBids = row['purpose'] == 'bids';
      rows.add({
        'id': 'deposit-${row['id']}',
        'date': row['createdAt'],
        'type': buyBids ? 'Bids' : 'Subscription',
        'details': buyBids
            ? '${row['connects']} Bids'
            : (row['planName'] == null || '${row['planName']}'.isEmpty
                  ? 'Membership plan'
                  : row['planName']),
        'client': null,
        // The page shows nothing once the deposit is approved.
        'status': row['status'] == 'APPROVED'
            ? null
            : _titleCase(row['status']),
        'amount': (row['amountUsd'] as num?)?.toDouble() ?? 0,
        'amountSign': 'debit',
      });
    }
    for (final row in _newestFirst(assignments, 'updatedAt')) {
      if (row['status'] != 'APPROVED') continue;
      final task = _taskById('${row['taskId']}');
      final withdrawal = _withdrawalFor('${row['id']}');
      rows.add({
        'id': 'earn-${row['id']}',
        'date': row['updatedAt'],
        'type': 'Client',
        'details': task?['title'] ?? 'Project',
        'client': task?['clientName'],
        'status': withdrawal == null
            ? 'Active'
            : _titleCase(withdrawal['status']),
        'amount':
            (row['payoutAmount'] as num?)?.toDouble() ??
            (task?['earningAmount'] as num?)?.toDouble() ??
            0,
        'amountSign': 'credit',
      });
    }
    for (final row in _newestFirst(withdrawals, 'createdAt')) {
      rows.add({
        'id': 'wd-${row['id']}',
        'date': row['createdAt'],
        'type': 'Withdrawal',
        'details': _blankTo(row['projectTitle'], row['method']) ?? 'Withdrawal',
        'client': row['clientName'],
        'status': _titleCase(row['status']),
        'amount': (row['amount'] as num?)?.toDouble() ?? 0,
        'amountSign': 'debit',
      });
    }
    for (final row in _newestFirst(walletTxs, 'createdAt').take(100)) {
      final reason = '${row['reason']}'.toLowerCase();
      if (reason.contains('task approved') ||
          reason.contains('withdrawal request') ||
          reason.contains('withdrawal rejected')) {
        continue;
      }
      rows.add({
        'id': 'wallet-${row['id']}',
        'date': row['createdAt'],
        'type': 'Other',
        'details': row['reason'],
        'client': null,
        'status': null,
        'amount': ((row['amount'] as num?)?.toDouble() ?? 0).abs(),
        'amountSign': row['type'] == 'CREDIT' ? 'credit' : 'debit',
      });
    }
    rows.sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));

    final clients =
        rows
            .map((row) => row['client'])
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final visible = rows
        .where(
          (row) =>
              (type == 'all' ||
                  type == row['type'] ||
                  (type == 'Earning' && row['type'] == 'Client')) &&
              (client == 'all' || row['client'] == client),
        )
        .toList();
    final start = (paging.page - 1) * paging.limit;
    final page = visible.skip(start).take(paging.limit).toList();

    return _json(200, {
      'availableBalance': storedBalance,
      'pendingEarnings':
          _total(
            assignments.where((row) => row['status'] == 'SUBMITTED'),
            (row) =>
                (row['payoutAmount'] as num?)?.toDouble() ??
                (_taskById('${row['taskId']}')?['earningAmount'] as num?)
                    ?.toDouble() ??
                0,
          ) +
          _total(
            withdrawals.where((row) => row['status'] == 'PENDING'),
            (row) => (row['amount'] as num?)?.toDouble() ?? 0,
          ),
      'hasPaymentMethod': billingMethods.isNotEmpty,
      'rows': page,
      'clients': clients,
      'total': visible.length,
      'page': paging.page,
      'limit': paging.limit,
      'totalPages': (visible.length / paging.limit).ceil().clamp(1, 1 << 31),
    });
  }

  /// `GET /api/reports/my-stats` → `buildMyStats`, with the route's own clamp of
  /// the two windows to 7, 15 or 30 days.
  http.Response _myStats(http.Request request) {
    if (!_signedIn(request)) return _unauthorised();
    if (financeBroken) {
      return _json(500, {'error': 'Unable to load the statistics.'});
    }
    final params = request.url.queryParameters;
    int window(String key, int fallback) {
      final days = int.tryParse(params[key] ?? '');
      return [7, 15, 30].contains(days) ? days! : fallback;
    }

    final proposalDays = window('proposalDays', 15);
    final profileDays = window('profileDays', 7);
    final now = DateTime.now().toUtc();
    final proposalSince = now.subtract(Duration(days: proposalDays - 1));
    final twelveMonthsAgo = DateTime.now().subtract(const Duration(days: 365));

    final decided = assignments
        .where((row) => ['APPROVED', 'REJECTED'].contains(row['status']))
        .toList();
    final approvedInWindow = assignments.where((row) {
      final updated = DateTime.tryParse('${row['updatedAt']}');
      return row['status'] == 'APPROVED' &&
          updated != null &&
          !updated.isBefore(twelveMonthsAgo);
    }).toList();
    final approvedCount = decided
        .where((row) => row['status'] == 'APPROVED')
        .length;

    // `buildProposalFunnel`: a pending bid only counts as viewed once the
    // client has written or the task became an assignment.
    final recentBids = bids
        .where(
          (row) =>
              !DateTime.parse('${row['createdAt']}').isBefore(proposalSince),
        )
        .toList();
    final messaged = chatRows.entries
        .where(
          (entry) => entry.value.any((row) => row['senderId'] != sessionId),
        )
        .map((entry) => entry.key)
        .toSet();
    final assignmentByTask = <String, Map<String, dynamic>>{
      for (final row in assignments)
        if (!DateTime.parse('${row['updatedAt']}').isBefore(proposalSince) ||
            !DateTime.parse('${row['createdAt']}').isBefore(proposalSince))
          '${row['taskId']}': row,
    };
    bool hired(Map<String, dynamic> bid) =>
        bid['status'] == 'AWARDED' ||
        assignmentByTask.containsKey('${bid['taskId']}');
    bool interviewed(Map<String, dynamic> bid) {
      final assignment = assignmentByTask['${bid['taskId']}'];
      if (assignment != null &&
          ['ACTIVE', 'SUBMITTED', 'APPROVED'].contains(assignment['status'])) {
        return true;
      }
      return messaged.contains('${bid['taskId']}');
    }

    final series = <Map<String, dynamic>>[];
    var views = 0, impressions = 0, clicks = 0;
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: profileDays - 1));
    for (var day = 0; day < profileDays; day++) {
      final date = start.add(Duration(days: day));
      final key =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final dayEvents = profileEvents.where((row) {
        final at = DateTime.tryParse('${row['createdAt']}')?.toLocal();
        return at != null &&
            '${at.year.toString().padLeft(4, '0')}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}' ==
                key;
      }).toList();
      final dayViews = dayEvents.where((row) => row['kind'] == 'VIEW').length;
      final dayImpressions = dayEvents
          .where((row) => row['kind'] == 'IMPRESSION')
          .length;
      final dayClicks = dayEvents.where((row) => row['kind'] == 'CLICK').length;
      views += dayViews;
      impressions += dayImpressions;
      clicks += dayClicks;
      series.add({
        'date': key,
        'label':
            '${_months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}',
        'views': dayViews,
        'impressions': dayImpressions,
        'clicks': dayClicks,
      });
    }

    return _json(200, {
      'twelveMonthEarnings': _total(approvedInWindow, _assignmentEarning),
      'jobSuccessScore': decided.isEmpty
          ? null
          : (approvedCount / decided.length * 100).round(),
      'connects': storedConnects,
      'nextMonthConnects': membership == null
          ? 0
          : (membership!['monthlyConnects'] as num?)?.toInt() ?? 0,
      'proposalFunnel': {
        'proposals': recentBids.length,
        'viewed': recentBids
            .where(
              (row) =>
                  row['status'] != 'PENDING' ||
                  messaged.contains('${row['taskId']}') ||
                  assignmentByTask.containsKey('${row['taskId']}'),
            )
            .length,
        'interviews': recentBids.where(interviewed).length,
        'hires': recentBids.where(hired).length,
      },
      'profileViews': views,
      'impressions': impressions,
      'clicks': clicks,
      'profileSeries': series,
    });
  }

  /// `GET /api/reports/weekly`. The two scopes answer differently: the
  /// freelancer summary carries the week's numbers and the client scope carries
  /// only `since` and `clients` — and needs an active Pro plan.
  http.Response _weekly(http.Request request) =>
      _weeklyBody(request, download: false);

  /// `GET /api/reports/weekly/download` — the same gate, `text/plain` answer.
  http.Response _weeklyDownload(http.Request request) =>
      _weeklyBody(request, download: true);

  http.Response _weeklyBody(http.Request request, {required bool download}) {
    if (!_signedIn(request)) return _unauthorised();
    final clientScope = request.url.queryParameters['scope'] == 'client';
    final now = DateTime.now().toUtc();
    // `activeMembership` only answers for a plan that is running, and
    // `isProPlan` is the name, compared the way the route compares it.
    final plan = membership;
    final pro =
        plan != null &&
        ['ACTIVE', 'PAST_DUE'].contains('${plan['status']}') &&
        !(DateTime.tryParse('${plan['expiresAt']}')?.isBefore(now) ?? true) &&
        '${plan['planName']}'.trim().toLowerCase() == 'pro';
    if (clientScope && !pro) {
      return _json(403, {
        'error': clientScope && download
            ? 'An active Pro plan is required to download the weekly client report.'
            : 'An active Pro plan is required to view the weekly client report.',
      });
    }
    if (financeBroken) {
      return _json(500, {'error': 'Unable to load the report.'});
    }

    final since = now.subtract(const Duration(days: 7));
    bool inWeek(Object? value) {
      final at = DateTime.tryParse('$value');
      return at != null && !at.isBefore(since);
    }

    final weekBids = bids.where((row) => inWeek(row['createdAt'])).toList();
    final approved = assignments
        .where((row) => row['status'] == 'APPROVED' && inWeek(row['updatedAt']))
        .toList();
    final submitted = assignments
        .where(
          (row) => row['status'] == 'SUBMITTED' && inWeek(row['updatedAt']),
        )
        .toList();
    final active = assignments
        .where(
          (row) => ['ACTIVE', 'SUBMITTED', 'APPROVED'].contains(row['status']),
        )
        .toList();
    final weekMessages = <String, int>{};
    for (final entry in chatRows.entries) {
      final count = entry.value.where((row) {
        final at = row['createdAt'];
        return at is DateTime && !at.isBefore(since);
      }).length;
      if (count > 0) weekMessages[entry.key] = count;
    }
    final messageCount = weekMessages.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );
    final earnings = _total(approved, _assignmentEarning);
    final projects = active.map((row) => row['taskId']).toSet().length;

    final byClient = <String, Map<String, dynamic>>{};
    void forClient(String name, void Function(Map<String, dynamic>) update) {
      final row = byClient.putIfAbsent(
        name,
        () => {
          'name': name,
          'profile':
              '/clients/${Uri.encodeComponent(name.toLowerCase().replaceAll(' ', '-'))}',
          'jobs': 0,
          'submitted': 0,
          'earned': 0.0,
          'proposals': 0,
          'messageCount': 0,
        },
      );
      update(row);
    }

    for (final row in active) {
      forClient(
        _displayName(_taskById('${row['taskId']}')?['clientName']),
        (each) => each['jobs'] = (each['jobs'] as int) + 1,
      );
    }
    for (final row in submitted) {
      forClient(
        _displayName(_taskById('${row['taskId']}')?['clientName']),
        (each) => each['submitted'] = (each['submitted'] as int) + 1,
      );
    }
    for (final row in approved) {
      final name = _displayName(_taskById('${row['taskId']}')?['clientName']);
      final amount = _assignmentEarning(row);
      forClient(
        name,
        (each) => each['earned'] = (each['earned'] as double) + amount,
      );
    }
    for (final row in weekBids) {
      forClient(
        _displayName(_taskById('${row['taskId']}')?['clientName']),
        (each) => each['proposals'] = (each['proposals'] as int) + 1,
      );
    }
    for (final entry in weekMessages.entries) {
      forClient(
        _displayName(_taskById(entry.key)?['clientName']),
        (each) =>
            each['messageCount'] = (each['messageCount'] as int) + entry.value,
      );
    }
    final clients = byClient.values.toList()
      ..sort(
        (a, b) => (b['earned'] as double).compareTo(a['earned'] as double),
      );

    if (clientScope) {
      if (!download) {
        return _json(200, {
          'report': {'since': since.toIso8601String(), 'clients': clients},
        });
      }
      final lines = [
        'Weekly client report',
        'Week of ${_shortDate(since)}',
        for (final row in clients)
          '${row['name']}: ${row['jobs']} jobs, ${row['proposals']} proposals, '
              r'$'
              '${(row['earned'] as double).toStringAsFixed(2)} earned',
      ];
      return http.Response(
        lines.join('\n'),
        200,
        headers: {
          'content-type': 'text/plain; charset=utf-8',
          'content-disposition':
              'attachment; filename="weekly-client-report.txt"',
          'cache-control': 'no-store',
        },
      );
    }

    if (!download) {
      return _json(200, {
        'report': {
          'since': since.toIso8601String(),
          'earnings': earnings,
          'projects': projects,
          'proposals': weekBids.length,
          'approvedCount': approved.length,
          'submittedCount': submitted.length,
          'messages': messageCount,
        },
      });
    }
    final lines = [
      'Weekly report',
      'Week of ${_shortDate(since)}',
      'Earnings: ${_usd(earnings)}',
      'Projects: $projects',
      'Proposals: ${weekBids.length}',
      'Approved: ${approved.length}',
      'Submitted: ${submitted.length}',
      'Messages: $messageCount',
    ];
    return http.Response(
      lines.join('\n'),
      200,
      headers: {
        'content-type': 'text/plain; charset=utf-8',
        'content-disposition': 'attachment; filename="weekly-report.txt"',
        'cache-control': 'no-store',
      },
    );
  }

  /// `GET /api/bids/my` → `buildMyProposals`: the session user's own bids,
  /// newest first and paged on the server, plus every status count and the
  /// ACTIVE/SUBMITTED work those bids became.
  http.Response _myProposals(http.Request request) {
    if (!_signedIn(request)) return _unauthorised();
    final params = request.url.queryParameters;
    final status = params['status'] ?? 'all';
    const statuses = ['PENDING', 'SHORTLISTED', 'AWARDED', 'REJECTED'];
    if (status != 'all' && !statuses.contains(status)) {
      return _json(400, {
        'error': 'Invalid status. Use all, PENDING, SHORTLISTED, AWARDED or REJECTED.',
      });
    }
    if (financeBroken) {
      return _json(500, {'error': 'Unable to load proposals.'});
    }
    final paging = _readPaging(params, defaultLimit: 50, maxLimit: 100);

    final mine = bids.where((row) => row['userId'] == sessionId).toList();
    final matching = _newestFirst(
      status == 'all'
          ? mine
          : mine.where((row) => row['status'] == status).toList(),
      'createdAt',
    );
    final start = (paging.page - 1) * paging.limit;

    return _json(200, {
      'proposals': [
        for (final row in matching.skip(start).take(paging.limit))
          () {
            final task = _taskById('${row['taskId']}');
            return <String, dynamic>{
              'id': row['id'],
              'taskId': row['taskId'],
              'title': task?['title'] ?? 'Project',
              'description': task?['description'] ?? '',
              'status': row['status'],
              'bidAmount': row['bidAmount'],
              'proposal': row['proposal'],
              'connectsSpent': row['connectsSpent'],
              'extraConnects': row['extraConnects'],
              'createdAt': row['createdAt'],
              'category': task?['categoryName'],
              'clientName': _displayName(task?['clientName']),
              'earningAmount':
                  (task?['earningAmount'] as num?)?.toDouble() ?? 0,
            };
          }(),
      ],
      'activeWork': [
        for (final row in _newestFirst(
          assignments
              .where(
                (each) =>
                    each['userId'] == sessionId &&
                    ['ACTIVE', 'SUBMITTED'].contains(each['status']),
              )
              .toList(),
          'createdAt',
        ).take(50))
          () {
            final task = _taskById('${row['taskId']}');
            return <String, dynamic>{
              'id': row['id'],
              'bidId': row['bidId'],
              'taskId': row['taskId'],
              'title': task?['title'] ?? 'Project',
              'status': row['status'],
              'statusLabel': row['status'] == 'SUBMITTED'
                  ? 'Waiting review'
                  : 'In progress',
              'payoutAmount': _assignmentEarning(row),
              'dueAt': row['dueAt'],
              'createdAt': row['createdAt'],
              'category': task?['categoryName'],
              'clientName': _displayName(task?['clientName']),
            };
          }(),
      ],
      'counts': {
        for (final value in statuses)
          value: mine.where((row) => row['status'] == value).length,
      },
      'total': matching.length,
      'page': paging.page,
      'limit': paging.limit,
      'totalPages': (matching.length / paging.limit).ceil().clamp(1, 1 << 31),
    });
  }

  // ---------------------------------------------------------------------------
  // Small mirrors of the backend helpers these five builders lean on.
  // ---------------------------------------------------------------------------

  bool _signedIn(http.Request request) =>
      !(sessionRevoked || !_hasSession(request));

  http.Response _unauthorised() => _json(401, {'error': 'Unauthorized'});

  Map<String, dynamic>? _taskById(String id) {
    for (final row in tasks) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  Map<String, dynamic>? _withdrawalFor(String assignmentId) {
    for (final row in withdrawals) {
      if (row['assignmentId'] == assignmentId) return row;
    }
    return null;
  }

  /// `payoutAmount ?? task.earningAmount`, the fallback both pages use.
  double _assignmentEarning(Map<String, dynamic> row) {
    final payout = row['payoutAmount'];
    if (payout is num) return payout.toDouble();
    final task = _taskById('${row['taskId']}')?['earningAmount'];
    return task is num ? task.toDouble() : 0;
  }

  double _total(
    Iterable<Map<String, dynamic>> rows,
    double Function(Map<String, dynamic> row) amount,
  ) => rows.fold<double>(0, (sum, row) => sum + amount(row));

  List<Map<String, dynamic>> _newestFirst(
    List<Map<String, dynamic>> rows,
    String key,
  ) => [...rows]..sort((a, b) => '${b[key]}'.compareTo('${a[key]}'));

  Object? _blankTo(Object? value, Object? fallback) {
    final text = '$value'.trim();
    if (text.isNotEmpty && text != 'null') return value;
    final other = '$fallback'.trim();
    return other.isEmpty || other == 'null' ? null : fallback;
  }

  /// `titleCaseStatus` from the transactions page.
  String _titleCase(Object? status) {
    final value = '${status ?? ''}';
    return switch (value) {
      'PAID' => 'Paid',
      'PENDING' => 'Pending',
      'REJECTED' => 'Rejected',
      'APPROVED' => 'Active',
      'ACTIVE' => 'Active',
      _ => value.isEmpty ? value : value[0] + value.substring(1).toLowerCase(),
    };
  }

  /// `resolveClientDisplayName`: a blank or missing name becomes the placeholder.
  String _displayName(Object? value) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? 'WorkingTrust Client' : text;
  }

  /// `readPaging`: clamped, never NaN, never negative.
  ({int page, int limit}) _readPaging(
    Map<String, String> params, {
    int defaultPage = 1,
    int defaultLimit = 50,
    int maxLimit = 200,
  }) {
    int read(String key, int fallback) {
      final value = int.tryParse(params[key] ?? '');
      return value == null || value == 0 ? fallback : value;
    }

    return (
      page: read('page', defaultPage).clamp(1, 1 << 31),
      limit: read('limit', defaultLimit).clamp(1, maxLimit),
    );
  }

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _shortDate(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}, ${date.year}';

  String _usd(double amount) =>
      '\$${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})\.)'), (m) => '${m[1]},')}';

  http.Response _json(int status, Object body, {Map<String, String>? headers}) {
    return http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json', ...?headers},
    );
  }
}
