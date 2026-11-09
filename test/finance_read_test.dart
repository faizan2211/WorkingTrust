import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/routes/app_routes.dart';
import 'package:working_trust/core/network/api_client.dart';
import 'package:working_trust/core/network/network_exceptions.dart';
import 'package:working_trust/core/network/session_store.dart';
import 'package:working_trust/features/find_work/controller/find_work_controller.dart';
import 'package:working_trust/features/finance/controller/overview_controller.dart';
import 'package:working_trust/features/finance/controller/proposals_controller.dart';
import 'package:working_trust/features/finance/controller/read_state.dart';
import 'package:working_trust/features/finance/controller/stats_controller.dart';
import 'package:working_trust/features/finance/controller/transactions_controller.dart';
import 'package:working_trust/features/finance/controller/wallet_controller.dart';
import 'package:working_trust/features/finance/controller/weekly_controller.dart';
import 'package:working_trust/features/finance/models/my_proposals.dart';
import 'package:working_trust/features/finance/models/my_stats.dart';
import 'package:working_trust/features/finance/models/transaction_feed.dart';
import 'package:working_trust/features/finance/models/weekly_report.dart';
import 'package:working_trust/features/finance/services/proposals_service.dart';
import 'package:working_trust/features/finance/services/reports_service.dart';
import 'package:working_trust/features/home/screens/home_screen.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';
import 'package:working_trust/features/profile/screens/wallet_screen.dart';
import 'package:working_trust/features/profile/screens/your_reports_screen.dart';

import 'fake_backend.dart';

/// The five read routes the Wallet, Reports, Transactions, My Stats, My
/// Proposals and My Reports screens are built on, run against the fake backend
/// that mirrors them. Every figure asserted here is one the fake's builders
/// computed from the tables it holds — these tests fail if the app instead
/// invents, re-adds or hardcodes a number.
final FakeBackend _backend = FakeBackend();

/// Drops every read so a test always starts from an unloaded controller.
void _clearReads() {
  WalletController.instance.clear();
  OverviewController.instance.clear();
  StatsController.instance.clear();
  TransactionsController.instance.clear();
  ProposalsController.instance.clear();
  WeeklyController.instance.clear();
  ProfileController.instance.clear();
  FindWorkController.instance.clear();
}

Map<String, WidgetBuilder> routeTable() =>
    Map<String, WidgetBuilder>.of(AppRoutes.routes)
      ..remove(Navigator.defaultRouteName);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Runs a read that the route is expected to refuse and hands back the
/// [NetworkException], so a test can assert the server's own sentence and
/// status code rather than a message the app wrote.
Future<NetworkException> _captureFailure(Future<Object?> read) async {
  try {
    await read;
  } on NetworkException catch (e) {
    return e;
  }
  throw StateError('The route answered instead of refusing.');
}

/// Waits for the reads a successful action started to land. Nothing here polls
/// the backend: the controllers are busy only because an action asked them.
Future<void> _letReadsFinish() async {
  for (var attempt = 0; attempt < 40; attempt++) {
    final busy =
        WalletController.instance.isBusy || ProposalsController.instance.isBusy;
    if (!busy) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  setUp(() async {
    _clearReads();
    await _backend.install();
    _backend.issueSessionCookie();
  });

  tearDown(_clearReads);

  group('wallet', () {
    test('reads its money and both ledgers from GET /api/wallet', () async {
      await WalletController.instance.load();
      final wallet = WalletController.instance.value;

      expect(WalletController.instance.state, ReadState.ready);
      expect(wallet.balance, 1240.50);
      expect(wallet.connects, 134);
      expect(_backend.countOf('/api/wallet'), 1);

      // The ledger rows, in the server's own newest-first order.
      expect(wallet.moneyActivity.map((row) => row.reason).toList(), [
        'Withdrawal request for ${_backend.tasks[1]['title']}',
        'Task approved: ${_backend.tasks[1]['title']}',
        'Referral bonus',
        'Manual adjustment',
      ]);
      expect(wallet.connectsActivity.first.delta, -40);

      // Approved jobs only, with the withdrawal the account filed against them.
      expect(wallet.earnings.map((row) => row.id).toList(), ['a4', 'a5']);
      expect(wallet.earnings.first.amount, 950);
      expect(wallet.earnings.first.withdrawalStatus, 'PENDING');
      expect(wallet.earnings.last.amount, 230);
      expect(wallet.earnings.last.withdrawalRequested, isTrue);
    });

    test('reports a pending deposit only while the server holds one', () async {
      await WalletController.instance.load();
      expect(WalletController.instance.value.pendingDeposit, isNull);

      // A Stripe checkout that was never paid leaves a PENDING deposit row.
      // The wallet shows what that row says; the app tracks no purchase itself.
      _backend.deposits['cs_test_unpaid'] = <String, dynamic>{
        'id': 'd90',
        'userId': 'u1',
        'planName': '60 Bids',
        'purpose': 'bids',
        'amountUsd': 20.0,
        'connects': 60,
        'status': 'PENDING',
        'fulfilled': false,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };

      await WalletController.instance.refresh();
      final deposit = WalletController.instance.value.pendingDeposit;
      expect(deposit?.packageName, '60 Bids');
      expect(deposit?.amountUsd, 20);
      expect(deposit?.status, 'PENDING');
      expect(deposit?.connects, 60);

      // Once the server marks it fulfilled it stops being a pending deposit.
      _backend.deposits['cs_test_unpaid']!['status'] = 'FULFILLED';
      await WalletController.instance.refresh();
      expect(WalletController.instance.value.pendingDeposit, isNull);
    });

    test(
      'a failed read is an error with the server sentence, then recovers',
      () async {
        _backend.financeBroken = true;
        await WalletController.instance.load();

        expect(WalletController.instance.state, ReadState.failed);
        expect(WalletController.instance.error, 'Unable to load the wallet.');
        expect(WalletController.instance.hasValue, isFalse);
        // A failed read leaves no money on screen, not a stale figure.
        expect(WalletController.instance.value.balance, isNull);

        _backend.financeBroken = false;
        await WalletController.instance.refresh();
        expect(WalletController.instance.state, ReadState.ready);
        expect(WalletController.instance.value.balance, 1240.50);
      },
    );

    test(
      'asks for nothing and says the session went when signed out',
      () async {
        await SessionStore.instance.clear();

        await WalletController.instance.load();
        await OverviewController.instance.load();

        expect(WalletController.instance.state, ReadState.failed);
        expect(WalletController.instance.sessionExpired, isTrue);
        expect(WalletController.instance.error, SessionExpiry.message);
        expect(_backend.countOf('/api/wallet'), 0);
        expect(_backend.countOf('/api/reports/overview'), 0);
      },
    );

    test(
      'a 401 mid-session reads as an expired session, not a retry',
      () async {
        await WalletController.instance.load();
        _backend.sessionRevoked = true;
        await WalletController.instance.refresh();

        expect(WalletController.instance.sessionExpired, isTrue);
        expect(WalletController.instance.error, SessionExpiry.message);
      },
    );

    test('a paid bid moves connects and the wallet reads that back', () async {
      await WalletController.instance.load();
      expect(WalletController.instance.value.connects, 134);

      _backend.storedConnects = 94;
      await WalletController.instance.refresh();
      expect(WalletController.instance.value.connects, 94);
      expect(_backend.countOf('/api/wallet'), 2);
    });

    test(
      'reads once when opened and never again without being asked',
      () async {
        await WalletController.instance.load();
        await WalletController.instance.load();
        await WalletController.instance.load(force: false);
        expect(_backend.countOf('/api/wallet'), 1);

        await WalletController.instance.refresh();
        expect(_backend.countOf('/api/wallet'), 2);
      },
    );
  });

  group('overview', () {
    test('shows the four money groups the report page computes', () async {
      await OverviewController.instance.load();
      final overview = OverviewController.instance.value;

      expect(overview.workInProgressAmount, 230);
      expect(overview.inReviewAmount, 480);
      expect(overview.pendingWithdrawalsAmount, 400);
      expect(overview.availableBalance, 1240.50);
    });

    test(
      'labels each job with the page status words and never a local guess',
      () async {
        await OverviewController.instance.load();
        final jobs = OverviewController.instance.value.jobs;

        expect(jobs.map((job) => job.id).toList(), ['a2', 'a1', 'a3']);
        expect(jobs.map((job) => job.statusLabel).toList(), [
          'In review',
          'In progress',
          'Needs revision',
        ]);
        // APPROVED work is settled and stays out of the list the page shows.
        expect(jobs.any((job) => job.status == 'APPROVED'), isFalse);
        expect(jobs.last.clientName, 'Amara');
        expect(jobs.first.earningAmount, 480);
      },
    );

    test('an account with no live jobs still reports the totals it has', () async {
      _backend.assignments.removeWhere(
        (row) => ['ACTIVE', 'SUBMITTED', 'REJECTED'].contains(row['status']),
      );
      await OverviewController.instance.load();

      // The four amounts are totals the route worked out for the account, so an
      // empty job list is a screen with its figures, not a blank page.
      expect(OverviewController.instance.state, ReadState.ready);
      expect(OverviewController.instance.value.jobs, isEmpty);
      expect(OverviewController.instance.value.availableBalance, 1240.50);
    });
  });

  group('transactions', () {
    test('merges the feed, drops the ledger rows that repeat a money row', () async {
      await TransactionsController.instance.load();
      final controller = TransactionsController.instance;

      expect(controller.availableBalance, 1240.50);
      // Submitted work (480) plus the pending withdrawal (400).
      expect(controller.pendingEarnings, 880);
      expect(controller.hasPaymentMethod, isFalse);
      expect(controller.total, 6);

      final details = controller.rows.map((row) => row.details).toList();
      // The approved earning and the withdrawal request already have their own
      // rows in the feed, so the route drops the two ledger rows that repeat
      // them; a movement the ledger alone carries stays.
      expect(
        details,
        isNot(contains('Task approved: ${_backend.tasks[1]['title']}')),
      );
      expect(
        details,
        isNot(contains('Withdrawal request for ${_backend.tasks[1]['title']}')),
      );
      expect(
        details,
        containsAll(<String>[
          'Referral bonus',
          'Manual adjustment',
          '${_backend.tasks[1]['title']}',
          '${_backend.tasks[0]['title']}',
        ]),
      );
    });

    test('filters on the server, not in the app', () async {
      await TransactionsController.instance.setType(
        TransactionFilter.withdrawal,
      );
      final controller = TransactionsController.instance;

      expect(controller.rows, hasLength(2));
      expect(controller.rows.every((row) => row.type == 'Withdrawal'), isTrue);
      expect(_backend.requests.last.url.queryParameters['type'], 'Withdrawal');

      await controller.setType(TransactionFilter.earning);
      expect(_backend.requests.last.url.queryParameters['type'], 'Earning');
      // The route's own alias for the Client rows.
      expect(
        TransactionsController.instance.rows.map((row) => row.type).toSet(),
        {'Client'},
      );
    });

    test(
      'a type the route does not know is refused with its own sentence',
      () async {
        final failure = await _captureFailure(
          ApiClient().get(
            '/api/reports/transactions',
            queryParameters: const {'type': 'Coffee'},
          ),
        );

        expect(failure.statusCode, 400);
        expect(
          failure.message,
          'Invalid type. Use all, Client, Withdrawal, Bids, Subscription or Other.',
        );
      },
    );

    test('pages on the server and appends the next page only once', () async {
      final first = await ReportsService.instance.fetchTransactions(
        page: 1,
        limit: 4,
      );
      expect(first.rows, hasLength(4));
      expect(first.total, 6);
      expect(first.totalPages, 2);

      final second = await ReportsService.instance.fetchTransactions(
        page: 2,
        limit: 4,
      );
      expect(second.rows, hasLength(2));
      expect(
        second.rows
            .map((row) => row.id)
            .toSet()
            .intersection(first.rows.map((row) => row.id).toSet()),
        isEmpty,
      );

      // The page a browser asks for beyond the last one answers with nothing
      // new, and the controller stops offering more.
      final beyond = await ReportsService.instance.fetchTransactions(
        page: 9,
        limit: 4,
      );
      expect(beyond.rows, isEmpty);
    });

    test(
      'the client list is the server\'s and narrows the same query',
      () async {
        await TransactionsController.instance.load();
        final controller = TransactionsController.instance;

        // The picker is the route's own distinct client names, with its "all"
        // entry first — not a list the app assembled from what it could see.
        final serverClients =
            controller.rows
                .map((row) => row.client)
                .whereType<String>()
                .where((name) => name.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        expect(serverClients, isNotEmpty);
        expect(controller.clientOptions, ['All Clients', ...serverClients]);

        await controller.setClient(serverClients.first);
        expect(
          _backend.requests.last.url.queryParameters['client'],
          serverClients.first,
        );
        expect(
          TransactionsController.instance.rows.map((row) => row.client).toSet(),
          {serverClients.first},
        );
      },
    );
  });

  group('my stats', () {
    test(
      'takes the figures from the existing route without recomputing',
      () async {
        await StatsController.instance.load();
        final stats = StatsController.instance.value;

        // 950 + 230 of approved work inside twelve months, 2 of 3 decided jobs.
        expect(stats.twelveMonthEarnings, 1180);
        expect(stats.jobSuccessScore, 67);
        expect(stats.earningsLabel, r'$1180.00');
        expect(stats.successLabel, '67%');
        expect(stats.connects, 134);
        expect(stats.nextMonthConnects, 0);
        expect(stats.bidBonusLabel, 'No connects scheduled for next month');
      },
    );

    test('a window change re-reads the route with the new parameter', () async {
      await StatsController.instance.setProfileDays(7);
      await StatsController.instance.load(force: true);
      expect(_backend.requests.last.url.queryParameters['profileDays'], '7');

      final readsBeforeChange = _backend.countOf('/api/reports/my-stats');
      await StatsController.instance.setProfileDays(30);
      expect(_backend.requests.last.url.queryParameters['profileDays'], '30');
      expect(StatsController.instance.value.profileSeries, hasLength(30));
      // The window change is what asked again: the route was read for it,
      // never recalculated on the device.
      expect(
        _backend.countOf('/api/reports/my-stats'),
        greaterThan(readsBeforeChange),
      );
    });

    test('the profile window counts only events inside it', () async {
      // The window is a setting the controller keeps, so a test that needs
      // seven days asks for it rather than trusting the last reader's value.
      await StatsController.instance.load(force: true);
      await StatsController.instance.setProfileDays(7);
      await StatsController.instance.load(force: true);
      expect(_backend.requests.last.url.queryParameters['profileDays'], '7');
      final stats = StatsController.instance.value;

      // Twelve days of activity were filed; the seeded 12-day-old view is out.
      expect(stats.profileViews, 3);
      expect(stats.impressions, 5);
      expect(stats.clicks, 2);
      // The series is that same window day by day: seven days, oldest first,
      // adding up to the count the route reported rather than a wider range.
      expect(stats.profileSeries, hasLength(7));
      expect(stats.profileSeries.first.views, 0);
      expect(
        stats.profileSeries.fold<int>(0, (sum, day) => sum + (day.views ?? 0)),
        stats.profileViews,
      );
    });

    test('an account with no decided job has no score, not a zero', () async {
      _backend.assignments.removeWhere(
        (row) => ['APPROVED', 'REJECTED'].contains(row['status']),
      );
      await StatsController.instance.load();

      expect(StatsController.instance.value.jobSuccessScore, isNull);
      expect(StatsController.instance.value.successLabel, 'No score yet');
    });

    test('the proposal funnel is the route\'s count of the bids', () async {
      _backend.seedProposalHistory();
      await StatsController.instance.load();
      final funnel = StatsController.instance.value.funnel;

      // pb4 is sixteen days old and falls outside the fifteen-day window.
      expect(funnel.proposals, 3);
      expect(funnel.hires, lessThanOrEqualTo(funnel.interviews));
      expect(funnel.interviews, lessThanOrEqualTo(funnel.viewed));
      expect(funnel.viewed, lessThanOrEqualTo(funnel.proposals));
    });
  });

  group('weekly reports', () {
    test('the summary is the week the route reports', () async {
      await WeeklyController.instance.load(WeeklyScope.summary);
      final report = WeeklyController.instance.reportFor(WeeklyScope.summary);

      expect(
        WeeklyController.instance.stateOf(WeeklyScope.summary),
        ReadState.ready,
      );
      expect(report?.since, isNotNull);
      // Only the approval inside the seven-day window counts: the other is
      // forty days old and belongs to the twelve-month total, not this week.
      expect(report?.earnings, 950);
      expect(report?.approvedCount, 1);
      expect(report?.earningsLabel, r'$950.00');
      expect(report?.rangeLabel, startsWith('Week of '));
      // The summary scope carries no client breakdown.
      expect(report?.clients, isEmpty);
    });

    test('the client breakdown is refused until the plan is Pro', () async {
      await WeeklyController.instance.load(WeeklyScope.client);

      expect(WeeklyController.instance.isLocked(WeeklyScope.client), isTrue);
      expect(
        WeeklyController.instance.stateOf(WeeklyScope.client),
        ReadState.empty,
      );
      expect(
        WeeklyController.instance.errorFor(WeeklyScope.client),
        'An active Pro plan is required to view the weekly client report.',
      );

      // A plan the route would not call active keeps the card locked: the lock
      // is the server's answer, never a name the app compared itself.
      _backend.membership = {
        'planName': 'Pro',
        'monthlyConnects': 120,
        'status': 'CANCELLED',
        'expiresAt': DateTime.now().toUtc().add(const Duration(days: 5)),
      };
      await WeeklyController.instance.load(WeeklyScope.client, force: true);
      expect(WeeklyController.instance.isLocked(WeeklyScope.client), isTrue);

      _backend.membership = {
        'planName': 'Pro',
        'monthlyConnects': 120,
        'status': 'ACTIVE',
        'expiresAt': DateTime.now().toUtc().add(const Duration(days: 5)),
      };
      await WeeklyController.instance.load(WeeklyScope.client, force: true);

      expect(WeeklyController.instance.isLocked(WeeklyScope.client), isFalse);
      final report = WeeklyController.instance.reportFor(WeeklyScope.client);
      expect(report?.clients, isNotEmpty);
      expect(report?.clients.first.name, isNotEmpty);
      expect(_backend.requests.last.url.queryParameters['scope'], 'client');
    });

    test('the download hands back the server text, both scopes', () async {
      final text = await WeeklyController.instance.download(
        WeeklyScope.summary,
      );

      expect(text, contains(r'Earnings: $950.00'));
      expect(text, contains('Proposals: '));
      expect(_backend.requests.last.url.path, '/api/reports/weekly/download');
      expect(WeeklyController.instance.downloadError, isEmpty);

      final locked = await WeeklyController.instance.download(
        WeeklyScope.client,
      );
      expect(locked, isNull);
      expect(WeeklyController.instance.isLocked(WeeklyScope.client), isTrue);
      expect(
        WeeklyController.instance.downloadError,
        'An active Pro plan is required to download the weekly client report.',
      );
    });

    test('a locked scope says so on the screen that shows it', () async {
      await WeeklyController.instance.load(WeeklyScope.client);

      expect(WeeklyController.instance.isLocked(WeeklyScope.client), isTrue);
      expect(
        WeeklyController.instance.errorFor(WeeklyScope.client),
        isNotEmpty,
      );
      // The summary the account is entitled to still reads normally beside it.
      await WeeklyController.instance.load(WeeklyScope.summary);
      expect(
        WeeklyController.instance.stateOf(WeeklyScope.summary),
        ReadState.ready,
      );
    });
  });

  group('proposals', () {
    test(
      'lists the bids, the work they became and every status count',
      () async {
        _backend.seedProposalHistory();
        await ProposalsController.instance.load();
        final controller = ProposalsController.instance;

        expect(controller.state, ReadState.ready);
        expect(controller.total, 4);
        expect(controller.counts.pending, 1);
        expect(controller.counts.shortlisted, 1);
        expect(controller.counts.awarded, 1);
        expect(controller.counts.rejected, 1);
        expect(controller.proposals.map((row) => row.id).toList(), [
          'pb1',
          'pb2',
          'pb3',
          'pb4',
        ]);
        expect(controller.proposals.first.category, 'E-Commerce');
        expect(controller.activeWork.map((row) => row.id).toList(), [
          'a6',
          'a1',
          'a2',
        ]);
        expect(controller.activeWork.first.statusLabel, 'In progress');
      },
    );

    test('a status filter is a server parameter, not a local view', () async {
      _backend.seedProposalHistory();
      await ProposalsController.instance.setStatus(BidStatus.rejected);

      expect(_backend.requests.last.url.queryParameters['status'], 'REJECTED');
      expect(ProposalsController.instance.proposals, hasLength(1));
      expect(ProposalsController.instance.proposals.first.status, 'REJECTED');
      // The counts keep describing the whole account, as the route's groupBy.
      expect(ProposalsController.instance.counts.pending, 1);
    });

    test('an unknown status is refused before the route queries', () async {
      final failure = await _captureFailure(
        ApiClient().get(
          '/api/bids/my',
          queryParameters: const {'status': 'MAYBE'},
        ),
      );

      expect(failure.statusCode, 400);
      expect(
        failure.message,
        'Invalid status. Use all, PENDING, SHORTLISTED, AWARDED or REJECTED.',
      );
    });

    test('pages the bids on the server', () async {
      _backend.seedProposalHistory();
      final first = await ProposalsService.instance.fetch(page: 1, limit: 3);
      expect(first.proposals, hasLength(3));
      expect(first.total, 4);
      expect(first.totalPages, 2);

      final second = await ProposalsService.instance.fetch(page: 2, limit: 3);
      expect(second.proposals, hasLength(1));
      expect(
        second.proposals
            .map((row) => row.id)
            .toSet()
            .intersection(first.proposals.map((row) => row.id).toSet()),
        isEmpty,
      );
    });

    test('a sent proposal re-reads both the list and the wallet', () async {
      await FindWorkController.instance.load();
      await ProposalsController.instance.load();
      await WalletController.instance.load();
      final before = ProposalsController.instance.total;
      expect(_backend.countOf('/api/bids/my'), 1);

      final project = FindWorkController.instance.results.first;
      final outcome = await FindWorkController.instance.apply(
        project,
        proposal: 'I have done this exact work twice before and can start now.',
      );

      expect(outcome.sent, isTrue);
      expect(outcome.spent, 40);

      // The submit re-reads both routes instead of writing numbers down. Those
      // reads are started without being awaited, so the test lets them finish.
      await _letReadsFinish();
      expect(_backend.countOf('/api/bids/my'), greaterThan(1));
      expect(_backend.countOf('/api/wallet'), greaterThan(1));
      expect(ProposalsController.instance.total, before + 1);
      expect(ProposalsController.instance.proposals.first.taskId, project.id);
      expect(WalletController.instance.value.connects, 94);
    });

    test(
      'an account with no bids sent lists nothing, and keeps its work',
      () async {
        await ProposalsController.instance.load();

        expect(ProposalsController.instance.proposals, isEmpty);
        expect(ProposalsController.instance.total, 0);
        expect(ProposalsController.instance.counts.pending, 0);
        expect(ProposalsController.instance.hasMore, isFalse);
        // The account is not empty overall: the work its earlier awards became
        // still has a tab, so the screen shows that rather than an empty state.
        expect(ProposalsController.instance.state, ReadState.ready);
        expect(ProposalsController.instance.activeWork, isNotEmpty);
      },
    );

    test('an account with neither bids nor active work is empty', () async {
      _backend.assignments.removeWhere(
        (row) => ['ACTIVE', 'SUBMITTED'].contains(row['status']),
      );
      await ProposalsController.instance.load();

      expect(ProposalsController.instance.state, ReadState.empty);
      expect(ProposalsController.instance.proposals, isEmpty);
      expect(ProposalsController.instance.activeWork, isEmpty);
    });
  });

  group('screens', () {
    testWidgets('the wallet paints the server rows', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(routes: routeTable(), home: const WalletScreen()),
      );
      await _settle(tester);

      expect(find.text(r'$1240.50'), findsOneWidget);
      expect(find.text('134'), findsOneWidget);
      expect(find.text('Money activity'), findsOneWidget);
      expect(find.text('Connects activity'), findsOneWidget);
      // The ledger's own reasons, and the deltas it reported, not a summary the
      // device wrote.
      expect(find.text('Referral bonus'), findsOneWidget);
      expect(find.text('Manual adjustment'), findsOneWidget);
      expect(find.text('-40'), findsOneWidget);
      expect(find.text('+60'), findsOneWidget);
      expect(find.text('No money activity yet.'), findsNothing);
      expect(find.text('No connects activity yet.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the reports screen unlocks the Pro card from a 403', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(routes: routeTable(), home: const YourReportsScreen()),
      );
      await _settle(tester);

      expect(find.text('Weekly Summary'), findsOneWidget);
      expect(find.text('Upgrade to Pro'), findsOneWidget);
      expect(find.text('Week of '), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the wallet opened from the shell reads the route once', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: routeTable(),
          home: const HomeScreen(initialTab: 3),
        ),
      );
      await _settle(tester);

      await tester.ensureVisible(find.text('Wallet'));
      await tester.pump();
      await tester.tap(find.text('Wallet'));
      await _settle(tester);

      expect(find.byType(WalletScreen), findsOneWidget);
      expect(_backend.countOf('/api/wallet'), 1);
      expect(tester.takeException(), isNull);
    });
  });
}
